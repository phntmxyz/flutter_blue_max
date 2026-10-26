package com.lib.flutter_blue_max;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.os.Looper;

import java.nio.ByteBuffer;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;
import org.robolectric.annotation.Implementation;
import org.robolectric.annotation.Implements;
import org.robolectric.shadows.ShadowBluetoothGatt;
import org.robolectric.util.ReflectionHelpers;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
@LooperMode(LooperMode.Mode.PAUSED)
public class FlutterBlueMaxPluginRestartTest {
    private static final String REMOTE_ID = "12:34:56:78:9A:BC";
    private final FlutterBlueMaxPlugin plugin = new FlutterBlueMaxPlugin();
    private final RecordingMessenger messenger = new RecordingMessenger();
    private BluetoothAdapter adapter;
    private BluetoothGattCallback callback;
    private Map<String, BluetoothGatt> connected;
    private Map<String, Integer> mtu;

    @Before
    public void setUp() {
        adapter = RuntimeEnvironment.getApplication().getSystemService(BluetoothManager.class).getAdapter();
        shadowOf(adapter).setState(BluetoothAdapter.STATE_ON);
        ReflectionHelpers.setField(plugin, "mBluetoothAdapter", adapter);
        ReflectionHelpers.setField(plugin, "methodChannel", new MethodChannel(messenger, "flutter_blue_max/methods"));
        callback = ReflectionHelpers.getField(plugin, "mGattCallback");
        connected = ReflectionHelpers.getField(plugin, "mConnectedDevices");
        mtu = ReflectionHelpers.getField(plugin, "mMtu");
    }

    @Test
    public void retiredGattCallbacksCannotRepopulateCachesOrReachDart() {
        BluetoothGatt oldGatt = addConnectedGatt();
        assertEquals(1, call("flutterRestart"));

        emitDataCallbacks(oldGatt);
        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(mtu.isEmpty());
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void closedGattCannotAffectReplacementForTheSameDevice() {
        BluetoothGatt oldGatt = addConnectedGatt();
        call("flutterRestart");
        callback.onConnectionStateChange(oldGatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        BluetoothGatt newGatt = addConnectedGatt();
        callback.onMtuChanged(newGatt, 64, 0);
        shadowOf(Looper.getMainLooper()).idle();
        messenger.events.clear();
        Map<String, byte[]> writes = ReflectionHelpers.getField(plugin, "mWriteChr");
        Map<String, byte[]> descriptors = ReflectionHelpers.getField(plugin, "mWriteDesc");
        writes.put(REMOTE_ID + ":180d:2a37::noinst", new byte[]{7});
        descriptors.put(REMOTE_ID + ":180d:2a37:2902::noinst", new byte[]{1, 0});

        emitDataCallbacks(oldGatt);
        shadowOf(Looper.getMainLooper()).idle();

        assertEquals(Integer.valueOf(64), mtu.get(REMOTE_ID));
        assertEquals(1, writes.size());
        assertEquals(1, descriptors.size());
        assertSame(newGatt, connected.get(REMOTE_ID));
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void eventsQueuedBeforeRestartAreDiscardedAtDelivery() {
        BluetoothGatt oldGatt = addConnectedGatt();
        callback.onMtuChanged(oldGatt, 100, 0);

        call("flutterRestart");
        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(mtu.isEmpty());
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void eventsQueuedBeforeGattReplacementAreDiscardedAtDelivery() {
        BluetoothGatt oldGatt = addConnectedGatt();
        callback.onMtuChanged(oldGatt, 100, 0);
        addConnectedGatt();

        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void newSessionStillDeliversAllDataCallbacks() {
        BluetoothGatt oldGatt = addConnectedGatt();
        call("flutterRestart");
        callback.onConnectionStateChange(oldGatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        assertEquals(0, call("connectedCount"));
        BluetoothGatt newGatt = addConnectedGatt();

        emitDataCallbacks(newGatt);
        shadowOf(Looper.getMainLooper()).idle();

        assertEquals(Integer.valueOf(100), mtu.get(REMOTE_ID));
        assertEquals(List.of("OnMtuChanged", "OnDiscoveredServices", "OnCharacteristicReceived",
            "OnCharacteristicWritten", "OnDescriptorRead", "OnDescriptorWritten", "OnReadRssi"), messenger.events);
    }

    @Test
    public void previousRestartTimeoutDoesNotCloseLaterRestartHandles() {
        long timeout = ReflectionHelpers.getStaticField(FlutterBlueMaxPlugin.class, "HOT_RESTART_DISCONNECT_TIMEOUT_MS");
        BluetoothGatt firstGatt = addConnectedGatt();
        call("flutterRestart");
        callback.onConnectionStateChange(firstGatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout / 2));
        BluetoothGatt secondGatt = addConnectedGatt();
        call("flutterRestart");

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout - timeout / 2));

        assertFalse(shadowOf(secondGatt).isClosed());
        assertEquals(1, call("connectedCount"));

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout / 2));

        assertTrue(shadowOf(secondGatt).isClosed());
        assertEquals(0, call("connectedCount"));
    }

    @Test
    public void retryKeepsTheOriginalTeardownDeadline() {
        long timeout = ReflectionHelpers.getStaticField(FlutterBlueMaxPlugin.class, "HOT_RESTART_DISCONNECT_TIMEOUT_MS");
        BluetoothGatt gatt = addConnectedGatt();
        call("flutterRestart");
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout / 2));
        call("flutterRestart");

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout - timeout / 2));

        assertTrue(shadowOf(gatt).isClosed());
        assertEquals(0, call("connectedCount"));
    }

    @Test
    public void pendingOnlyGattWaitsForTerminalDisconnect() {
        BluetoothGatt gatt = addPendingGatt();
        assertTrue(connected.isEmpty());

        assertEquals(1, call("flutterRestart"));
        assertFalse(shadowOf(gatt).isClosed());
        callback.onConnectionStateChange(gatt, 0, BluetoothProfile.STATE_DISCONNECTED);

        assertTrue(shadowOf(gatt).isClosed());
        assertEquals(0, call("connectedCount"));
        shadowOf(Looper.getMainLooper()).idle();
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void pendingGattThatConnectsLateStaysRetired() {
        BluetoothGatt gatt = addPendingGatt();
        assertEquals(1, call("flutterRestart"));

        callback.onConnectionStateChange(gatt, 0, BluetoothProfile.STATE_CONNECTED);

        assertTrue(connected.isEmpty());
        assertEquals(1, call("connectedCount"));
        assertFalse(shadowOf(gatt).isClosed());
        callback.onConnectionStateChange(gatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        assertEquals(0, call("connectedCount"));
        assertTrue(shadowOf(gatt).isClosed());
        shadowOf(Looper.getMainLooper()).idle();
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    public void oldConnectionCallbacksCannotRemoveNewPendingGatt() {
        BluetoothGatt oldGatt = addPendingGatt();
        assertEquals(1, call("flutterRestart"));
        callback.onConnectionStateChange(oldGatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        assertEquals(0, call("connectedCount"));
        BluetoothGatt newGatt = addPendingGatt();
        Map<String, BluetoothGatt> pending = ReflectionHelpers.getField(plugin, "mCurrentlyConnectingDevices");
        assertSame(newGatt, pending.get(REMOTE_ID));

        callback.onConnectionStateChange(oldGatt, 0, BluetoothProfile.STATE_CONNECTED);
        callback.onConnectionStateChange(oldGatt, 0, BluetoothProfile.STATE_DISCONNECTED);

        assertSame(newGatt, pending.get(REMOTE_ID));
        assertFalse(shadowOf(newGatt).isClosed());
        shadowOf(Looper.getMainLooper()).idle();
        assertTrue(messenger.events.isEmpty());
        callback.onConnectionStateChange(newGatt, 0, BluetoothProfile.STATE_CONNECTED);
        assertSame(newGatt, connected.get(REMOTE_ID));
    }

    @Test
    public void pendingAutoConnectGattIsCountedOnceAndClosesOnDeadline() {
        BluetoothGatt gatt = addPendingGatt();
        Map<String, BluetoothGatt> autoConnect = ReflectionHelpers.getField(plugin, "mAutoConnected");
        autoConnect.put(REMOTE_ID, gatt);
        assertSame(gatt, autoConnect.get(REMOTE_ID));
        assertEquals(1, call("flutterRestart"));
        assertTrue(autoConnect.isEmpty());
        long timeout = ReflectionHelpers.getStaticField(FlutterBlueMaxPlugin.class, "HOT_RESTART_DISCONNECT_TIMEOUT_MS");

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(timeout));

        assertEquals(0, call("connectedCount"));
        assertTrue(shadowOf(gatt).isClosed());
        assertTrue(messenger.events.isEmpty());
    }

    @Test
    @Config(shadows = ThrowingDisconnectGattShadow.class)
    public void disconnectFailureClosesRetiredGattWithoutBlockingRestart() {
        BluetoothGatt gatt = addPendingGatt();
        assertFalse(shadowOf(gatt).isClosed());

        assertEquals(0, call("flutterRestart"));

        assertTrue(shadowOf(gatt).isClosed());
        assertEquals(0, call("connectedCount"));
    }

    @Test
    @Config(sdk = 34)
    public void queuedL2capConnectCannotOpenSocketAfterRestart() throws InterruptedException {
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT);
        call("connectedCount"); // creates the L2CAP manager
        L2CapChannelManager manager = ReflectionHelpers.getField(plugin, "l2CapChannelManager");
        List<L2CapInfo> channels = ReflectionHelpers.getField(manager, "openL2CapChannelInfos");
        RecordingResult opened = new RecordingResult();
        manager.openL2CapChannel(REMOTE_ID, 0x80, true, opened);
        L2CapClientChannel channel = ((ClientSocketInfo) channels.get(0)).l2capChannel;
        CountDownLatch release = new CountDownLatch(1);
        channel.ioExecutor.execute(() -> {
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        RecordingResult reopened = new RecordingResult();
        manager.openL2CapChannel(REMOTE_ID, 0x80, true, reopened);

        call("flutterRestart");
        release.countDown();
        assertTrue(channel.ioExecutor.awaitTermination(5, TimeUnit.SECONDS));
        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(opened.succeeded);
        assertEquals("channel_closed", reopened.errorCode);
        assertNull(channel.getSocket());
        assertTrue(channels.isEmpty());
    }

    @Implements(BluetoothGatt.class)
    public static class ThrowingDisconnectGattShadow extends ShadowBluetoothGatt {
        @Implementation
        public void disconnect() {
            throw new IllegalStateException("simulated disconnect failure");
        }
    }

    private BluetoothGatt addPendingGatt() {
        BluetoothGatt gatt = ShadowBluetoothGatt.newInstance(adapter.getRemoteDevice(REMOTE_ID));
        Map<String, BluetoothGatt> pending = ReflectionHelpers.getField(plugin, "mCurrentlyConnectingDevices");
        pending.put(REMOTE_ID, gatt);
        assertSame(gatt, pending.get(REMOTE_ID));
        return gatt;
    }

    private BluetoothGatt addConnectedGatt() {
        BluetoothGatt gatt = ShadowBluetoothGatt.newInstance(adapter.getRemoteDevice(REMOTE_ID));
        connected.put(REMOTE_ID, gatt);
        return gatt;
    }

    @SuppressWarnings("deprecation") // Exercise the Android 12 and earlier callback overloads too.
    private void emitDataCallbacks(BluetoothGatt gatt) {
        BluetoothGattService service = new BluetoothGattService(
            UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb"), BluetoothGattService.SERVICE_TYPE_PRIMARY);
        BluetoothGattCharacteristic characteristic = new BluetoothGattCharacteristic(
            UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb"), BluetoothGattCharacteristic.PROPERTY_READ, 0);
        BluetoothGattDescriptor descriptor = new BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"), 0);
        service.addCharacteristic(characteristic);
        characteristic.addDescriptor(descriptor);
        characteristic.setValue(new byte[]{7});
        descriptor.setValue(new byte[]{1, 0});

        callback.onMtuChanged(gatt, 100, 0);
        callback.onServicesDiscovered(gatt, 0);
        callback.onCharacteristicRead(gatt, characteristic, 0);
        callback.onCharacteristicWrite(gatt, characteristic, 0);
        callback.onDescriptorRead(gatt, descriptor, 0);
        callback.onDescriptorWrite(gatt, descriptor, 0);
        callback.onReadRemoteRssi(gatt, -50, 0);
    }

    private Object call(String method) {
        Object[] value = new Object[1];
        plugin.onMethodCall(new MethodCall(method, null), new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                value[0] = result;
            }

            @Override
            public void error(String code, String message, Object details) {
                throw new AssertionError(code + ": " + message);
            }

            @Override
            public void notImplemented() {
                throw new AssertionError("Unexpected method: " + method);
            }
        });
        return value[0];
    }

    private static class RecordingResult implements MethodChannel.Result {
        boolean succeeded;
        String errorCode;

        @Override
        public void success(Object result) {
            succeeded = true;
        }

        @Override
        public void error(String code, String message, Object details) {
            errorCode = code;
        }

        @Override
        public void notImplemented() {
            throw new AssertionError("Unexpected notImplemented");
        }
    }

    private static class RecordingMessenger implements BinaryMessenger {
        final List<String> events = new ArrayList<>();

        @Override
        public void send(String channel, ByteBuffer message) {
            send(channel, message, null);
        }

        @Override
        public void send(String channel, ByteBuffer message, BinaryReply reply) {
            message.flip();
            events.add(StandardMethodCodec.INSTANCE.decodeMethodCall(message).method);
        }

        @Override
        public void setMessageHandler(String channel, BinaryMessageHandler handler) {}
    }
}
