package com.lib.flutter_blue_max;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;
import org.robolectric.shadow.api.Shadow;
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
    public void eventsQueuedBeforeDisconnectStillReachDart() {
        BluetoothGatt gatt = addConnectedGatt();
        BluetoothGattService service = new BluetoothGattService(
            UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb"), BluetoothGattService.SERVICE_TYPE_PRIMARY);
        BluetoothGattCharacteristic characteristic = new BluetoothGattCharacteristic(
            UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb"), BluetoothGattCharacteristic.PROPERTY_WRITE, 0);
        service.addCharacteristic(characteristic);

        // e.g. a reboot command: the peripheral acks the write, then drops the link
        callback.onCharacteristicWrite(gatt, characteristic, 0);
        callback.onConnectionStateChange(gatt, 0, BluetoothProfile.STATE_DISCONNECTED);
        shadowOf(Looper.getMainLooper()).idle();

        assertEquals(List.of("OnCharacteristicWritten", "OnConnectionStateChanged"), messenger.events);
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
        CountDownLatch queued = new CountDownLatch(1);
        channel.ioExecutor.execute(() -> {
            queued.countDown();
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        assertTrue(queued.await(5, TimeUnit.SECONDS));
        shadowOf(Looper.getMainLooper()).idle();
        assertTrue(opened.succeeded);
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

    private ServerSocketInfo newServer(List<String> events) {
        BluetoothServerSocket socket = Shadow.newInstanceOf(BluetoothServerSocket.class);
        return new ServerSocketInfo(socket,
            (device, psm) -> events.add("connected"),
            (device, psm, data) -> events.add("data"),
            (device, psm) -> events.add("closed"), plugin);
    }

    @Test
    @Config(sdk = 34, shadows = {AcceptedSocketShadow.class, ListenerSocketShadow.class})
    public void socketReturnedAfterListenerRetirementIsClosedWithoutOpeningStreams() throws IOException {
        List<String> events = new ArrayList<>();
        ServerSocketInfo server = newServer(events);
        server.closeSocket();
        BluetoothSocket socket = Shadow.newInstanceOf(BluetoothSocket.class);
        AcceptedSocketShadow shadow = Shadow.extract(socket);

        server.adoptAcceptedSocket(socket);
        server.acceptConnections(); // retirement cannot be undone by retry
        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(shadow.closed);
        assertEquals(0, shadow.streamRequests);
        assertNull(server.getAnyL2CapChannel());
        assertTrue(events.isEmpty());
    }

    @Test
    @Config(sdk = 34, shadows = {AcceptedSocketShadow.class, ListenerSocketShadow.class})
    public void listenerRetirementOwnsSocketWhileStreamSetupIsInFlight() throws Exception {
        List<String> events = new ArrayList<>();
        ServerSocketInfo server = newServer(events);
        BluetoothSocket socket = Shadow.newInstanceOf(BluetoothSocket.class);
        AcceptedSocketShadow shadow = Shadow.extract(socket);
        shadow.entered = new CountDownLatch(1);
        shadow.release = new CountDownLatch(1);
        AtomicReference<Throwable> failure = new AtomicReference<>();
        Thread accept = new Thread(() -> {
            try { server.adoptAcceptedSocket(socket); }
            catch (Throwable e) { failure.set(e); }
        });
        accept.start();
        assertTrue(shadow.entered.await(5, TimeUnit.SECONDS));
        assertTrue(server.getAnyL2CapChannel() != null);
        Thread close = new Thread(server::closeSocket);
        close.start();
        // Wait until retirement wins the owner lock, before releasing I/O.
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        boolean retired = false;
        while (!retired && System.nanoTime() < deadline) {
            synchronized (server) { retired = ReflectionHelpers.getField(server, "retired"); }
            Thread.yield();
        }
        shadow.release.countDown();
        accept.join(5000);
        close.join(5000);
        shadowOf(Looper.getMainLooper()).idle();

        assertTrue(retired);
        assertFalse(accept.isAlive());
        assertFalse(close.isAlive());
        assertNull(failure.get());
        assertTrue(shadow.closed);
        assertNull(server.getAnyL2CapChannel());
        assertTrue(events.isEmpty());
    }

    @Test
    @Config(sdk = 34, shadows = {AcceptedSocketShadow.class, ListenerSocketShadow.class})
    public void acceptedSocketEventsKeepTheirOriginalSessionUntilDelivery() throws IOException {
        List<String> events = new ArrayList<>();
        ServerSocketInfo old = newServer(events);
        old.adoptAcceptedSocket(Shadow.newInstanceOf(BluetoothSocket.class));
        assertTrue(old.getAnyL2CapChannel() != null);
        call("flutterRestart");
        old.closeSocket();
        shadowOf(Looper.getMainLooper()).idle();
        assertTrue(events.isEmpty());

        ServerSocketInfo current = newServer(events);
        current.adoptAcceptedSocket(Shadow.newInstanceOf(BluetoothSocket.class));
        shadowOf(Looper.getMainLooper()).idle();
        assertEquals(List.of("connected"), events);
        current.closeSocket();
    }

    @Implements(BluetoothServerSocket.class)
    public static class ListenerSocketShadow {
        @Implementation public int getPsm() { return 0x81; }
        @Implementation public void close() {}
        @Implementation public BluetoothSocket accept() throws IOException {
            throw new IOException("No socket queued");
        }
    }

    @Implements(BluetoothSocket.class)
    public static class AcceptedSocketShadow {
        volatile boolean closed;
        int streamRequests;
        CountDownLatch entered;
        CountDownLatch release;
        @Implementation public InputStream getInputStream() throws IOException {
            streamRequests++;
            if (entered != null) {
                entered.countDown();
                try {
                    if (!release.await(5, TimeUnit.SECONDS)) throw new IOException("Test latch timed out");
                } catch (InterruptedException e) { throw new IOException(e); }
            }
            return new ByteArrayInputStream(new byte[0]);
        }
        @Implementation public OutputStream getOutputStream() {
            return new ByteArrayOutputStream();
        }
        @Implementation public BluetoothDevice getRemoteDevice() {
            return BluetoothAdapter.getDefaultAdapter().getRemoteDevice(REMOTE_ID);
        }
        @Implementation public boolean isConnected() { return !closed; }
        @Implementation public void close() { closed = true; }
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
