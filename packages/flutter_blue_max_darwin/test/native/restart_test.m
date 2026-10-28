#import "FlutterBlueMaxPlugin.h"

// Exercise the real plugin; only the CoreBluetooth/Flutter boundaries are faked.
@interface FlutterBlueMaxPlugin (RestartTests)
- (void)checkForMtuChangesCallback;
@end

@protocol RestartTestPeripheralManagerDelegate
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didPublishL2CAPChannel:(CBL2CAPPSM)PSM error:(NSError *)error;
- (void)peripheralManager:(CBPeripheralManager *)peripheral didUnpublishL2CAPChannel:(CBL2CAPPSM)PSM error:(NSError *)error;
@end

@interface RecordingMessenger : NSObject<FlutterBinaryMessenger>
@property(nonatomic) NSMutableArray<FlutterMethodCall *> *events;
@end

@implementation RecordingMessenger
- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [NSMutableArray new];
    }
    return self;
}
- (void)sendOnChannel:(NSString *)channel message:(NSData *)message {
    [self.events addObject:[[FlutterStandardMethodCodec sharedInstance] decodeMethodCall:message]];
}
- (void)sendOnChannel:(NSString *)channel message:(NSData *)message binaryReply:(FlutterBinaryReply)reply {
    [self sendOnChannel:channel message:message];
}
- (FlutterBinaryMessengerConnection)setMessageHandlerOnChannel:(NSString *)channel
                                        binaryMessageHandler:(FlutterBinaryMessageHandler)handler {
    return 0;
}
- (void)cleanUpConnection:(FlutterBinaryMessengerConnection)connection {}
@end

@interface TestRegistrar : NSObject
@property(nonatomic) RecordingMessenger *messenger;
@property(nonatomic) FlutterBlueMaxPlugin *plugin;
@end

@implementation TestRegistrar
- (void)addMethodCallDelegate:(FlutterBlueMaxPlugin *)delegate channel:(FlutterMethodChannel *)channel {
    self.plugin = delegate;
}
@end

@interface TestPeripheral : NSObject<NSCopying>
@property(nonatomic) NSUUID *identifier;
@property(nonatomic) NSString *name;
@property(nonatomic, weak) id delegate;
@property(nonatomic) CBPeripheralState state;
@property(nonatomic) NSArray *services;
@property(nonatomic) NSUInteger discoveryRequests;
@end

@implementation TestPeripheral
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (NSUInteger)maximumWriteValueLengthForType:(CBCharacteristicWriteType)type {
    return 61;
}
- (void)discoverCharacteristics:(NSArray *)uuids forService:(CBService *)service {
    self.discoveryRequests++;
}
- (void)discoverIncludedServices:(NSArray *)uuids forService:(CBService *)service {
    self.discoveryRequests++;
}
- (void)discoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic {
    self.discoveryRequests++;
}
@end

@interface TestCentralManager : NSObject
@property(nonatomic) NSUInteger cancellations;
@property(nonatomic) CBManagerState state;
@property(nonatomic) TestPeripheral *retrievedPeripheral;
@property(nonatomic) NSUInteger connectRequests;
@property(nonatomic) NSUInteger scanRequests;
@property(nonatomic, weak) id delegate;
@end

@implementation TestCentralManager
- (instancetype)init {
    self = [super init];
    if (self) _state = CBManagerStatePoweredOn;
    return self;
}
- (NSArray *)retrievePeripheralsWithIdentifiers:(NSArray *)identifiers {
    return self.retrievedPeripheral ? @[self.retrievedPeripheral] : @[];
}
- (void)connectPeripheral:(CBPeripheral *)peripheral options:(NSDictionary *)options {
    self.connectRequests++;
    self.retrievedPeripheral.state = CBPeripheralStateConnecting;
}
- (void)stopScan {}
- (void)scanForPeripheralsWithServices:(NSArray *)services options:(NSDictionary *)options {
    NSCAssert(self.state == CBManagerStatePoweredOn, @"Scan called before manager ready");
    self.scanRequests++;
}
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    self.cancellations++;
}
@end

@interface TestPeripheralManager : NSObject
@property(nonatomic) CBManagerState state;
@property(nonatomic) NSUInteger publishRequests;
@property(nonatomic) NSMutableArray<NSNumber *> *unpublished;
@end

@implementation TestPeripheralManager
- (instancetype)init {
    self = [super init];
    if (self) {
        _state = CBManagerStatePoweredOn;
        _unpublished = [NSMutableArray new];
    }
    return self;
}
- (void)publishL2CAPChannelWithEncryption:(BOOL)encryptionRequired {
    self.publishRequests++;
}
- (void)unpublishL2CAPChannel:(CBL2CAPPSM)PSM {
    [self.unpublished addObject:@(PSM)];
}
@end

// Keep manager construction at its native boundary; the production plugin and
// all delegate/retirement paths run unchanged.
@interface TestPlugin : FlutterBlueMaxPlugin
@property(nonatomic) BOOL delayManagerReadiness;
@end
@implementation TestPlugin
- (CBCentralManager *)createCentralManager {
    TestCentralManager *manager = [TestCentralManager new];
    if (self.delayManagerReadiness) manager.state = CBManagerStateUnknown;
    return (id)manager;
}
@end

@interface TestChannel : NSObject
@property(nonatomic) CBL2CAPPSM PSM;
@property(nonatomic) NSInputStream *inputStream;
@property(nonatomic) NSOutputStream *outputStream;
@end
@implementation TestChannel
@end

static id Call(FlutterBlueMaxPlugin *plugin, NSString *method) {
    __block id response = nil;
    [plugin handleMethodCall:[FlutterMethodCall methodCallWithMethodName:method arguments:nil]
                      result:^(id value) { response = value; }];
    NSCAssert(![response isKindOfClass:[FlutterError class]], @"Unexpected platform error: %@", response);
    return response;
}

static TestRegistrar *CreatePlugin(TestPeripheral **peripheralOut) {
    TestRegistrar *registrar = [TestRegistrar new];
    registrar.messenger = [RecordingMessenger new];
    [TestPlugin registerWithRegistrar:(id)registrar];
    [registrar.plugin setValue:[TestCentralManager new] forKey:@"centralManager"];
    [registrar.plugin setValue:@0 forKey:@"logLevel"];

    TestPeripheral *peripheral = [TestPeripheral new];
    peripheral.identifier = [[NSUUID alloc] initWithUUIDString:@"12345678-1234-1234-1234-123456789abc"];
    peripheral.name = @"Test peripheral";
    peripheral.state = CBPeripheralStateConnected;
    peripheral.services = @[];
    NSMutableDictionary *connected = [registrar.plugin valueForKey:@"connectedPeripherals"];
    connected[peripheral.identifier.UUIDString] = peripheral;
    *peripheralOut = peripheral;
    return registrar;
}

static void FinishRestart(TestRegistrar *registrar, TestPeripheral *peripheral) {
    peripheral.state = CBPeripheralStateDisconnected;
    [registrar.plugin centralManager:[registrar.plugin valueForKey:@"centralManager"]
            didDisconnectPeripheral:(id)peripheral error:nil];
    NSCAssert([Call(registrar.plugin, @"connectedCount") isEqual:@0], @"Restart did not finish");
    [[registrar.plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestMtuTimerDuringRestart(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    [registrar.plugin checkForMtuChangesCallback];
    NSCAssert(registrar.messenger.events.count == 1, @"Active MTU event missing");
    [registrar.messenger.events removeAllObjects];

    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Teardown should be pending");
    [registrar.plugin checkForMtuChangesCallback];

    NSCAssert(registrar.messenger.events.count == 0, @"Old MTU reached the new isolate");
    NSCAssert([[registrar.plugin valueForKey:@"peripheralMtu"] count] == 0, @"Old MTU repopulated the cache");
    FinishRestart(registrar, peripheral);
    NSCAssert(registrar.messenger.events.count == 0, @"Old disconnect reached the new isolate");
}

static void TestPeripheralCallbacksDuringRestart(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    CBMutableService *service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"180d"] primary:YES];
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]
        initWithType:[CBUUID UUIDWithString:@"2a37"] properties:CBCharacteristicPropertyRead
        value:[NSData data] permissions:CBAttributePermissionsReadable];
    CBMutableDescriptor *descriptor = [[CBMutableDescriptor alloc] initWithType:[CBUUID UUIDWithString:@"2901"]
                                                                 value:@"Test"];
    characteristic.descriptors = @[descriptor];
    service.characteristics = @[characteristic];
    peripheral.services = @[service];
    Call(plugin, @"flutterRestart");

    [plugin peripheral:(id)peripheral didDiscoverServices:nil];
    [plugin peripheral:(id)peripheral didDiscoverCharacteristicsForService:service error:nil];
    [plugin peripheral:(id)peripheral didDiscoverDescriptorsForCharacteristic:characteristic error:nil];
    [plugin peripheral:(id)peripheral didDiscoverIncludedServicesForService:service error:nil];
    [plugin peripheral:(id)peripheral didUpdateValueForCharacteristic:characteristic error:nil];
    [plugin peripheral:(id)peripheral didWriteValueForCharacteristic:characteristic error:nil];
    [plugin peripheral:(id)peripheral didUpdateNotificationStateForCharacteristic:characteristic error:nil];
    [plugin peripheral:(id)peripheral didUpdateValueForDescriptor:descriptor error:nil];
    [plugin peripheral:(id)peripheral didWriteValueForDescriptor:descriptor error:nil];
    [plugin peripheralDidUpdateName:(id)peripheral];
    [plugin peripheral:(id)peripheral didModifyServices:@[service]];
    [plugin peripheral:(id)peripheral didReadRSSI:@(-50) error:nil];
    [plugin peripheralIsReadyToSendWriteWithoutResponse:(id)peripheral];

    NSCAssert(registrar.messenger.events.count == 0, @"Old peripheral events reached Dart");
    NSCAssert(peripheral.discoveryRequests == 0, @"Old callbacks started more discovery work");
    NSCAssert([[plugin valueForKey:@"servicesToDiscover"] count] == 0, @"Discovery state repopulated");
    NSCAssert([[plugin valueForKey:@"characteristicsToDiscover"] count] == 0, @"Characteristic state repopulated");
    FinishRestart(registrar, peripheral);
}

static void TestNewSessionEvents(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    Call(registrar.plugin, @"flutterRestart");
    FinishRestart(registrar, peripheral);
    peripheral.state = CBPeripheralStateConnected;
    [[registrar.plugin valueForKey:@"currentlyConnectingPeripherals"] setObject:peripheral forKey:peripheral.identifier.UUIDString];
    [registrar.plugin centralManager:[registrar.plugin valueForKey:@"centralManager"]
               didConnectPeripheral:(id)peripheral];
    [registrar.messenger.events removeAllObjects];

    [registrar.plugin checkForMtuChangesCallback];
    [registrar.plugin peripheralDidUpdateName:(id)peripheral];
    [registrar.plugin peripheral:(id)peripheral didReadRSSI:@(-50) error:nil];

    NSArray *methods = [registrar.messenger.events valueForKey:@"method"];
    NSArray *expected = @[@"OnMtuChanged", @"OnNameChanged", @"OnReadRssi"];
    NSCAssert([methods isEqual:expected], @"New events missing: %@", methods);
}

static TestRegistrar *CreatePendingPlugin(TestPeripheral **peripheralOut) {
    TestRegistrar *registrar = CreatePlugin(peripheralOut);
    TestPeripheral *peripheral = *peripheralOut;
    peripheral.state = CBPeripheralStateConnecting;
    NSMutableDictionary *connected = [registrar.plugin valueForKey:@"connectedPeripherals"];
    NSMutableDictionary *pending = [registrar.plugin valueForKey:@"currentlyConnectingPeripherals"];
    [connected removeAllObjects];
    pending[peripheral.identifier.UUIDString] = peripheral;
    NSCAssert(connected.count == 0 && pending.count == 1, @"Pending-only setup failed");
    return registrar;
}

static void TestPendingConnectionTeardown(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePendingPlugin(&peripheral);
    TestCentralManager *central = [registrar.plugin valueForKey:@"centralManager"];
    NSCAssert(central.cancellations == 0, @"Unexpected cancellation before restart");

    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Pending connection was not counted");
    NSCAssert(central.cancellations == 1, @"Pending connection was not cancelled");
    NSCAssert([Call(registrar.plugin, @"connectedCount") isEqual:@1], @"Pending connection drained too early");
    peripheral.state = CBPeripheralStateDisconnected;
    [registrar.plugin centralManager:(id)central didFailToConnectPeripheral:(id)peripheral error:nil];

    NSCAssert([Call(registrar.plugin, @"connectedCount") isEqual:@0], @"Failed connection did not finish teardown");
    NSCAssert(registrar.messenger.events.count == 0, @"Old failed-connect event reached Dart");
    [[registrar.plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestPendingConnectionCompletesDuringRestart(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePendingPlugin(&peripheral);
    TestCentralManager *central = [registrar.plugin valueForKey:@"centralManager"];
    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Restart did not begin");
    NSCAssert(central.cancellations == 1, @"Initial cancellation missing");

    peripheral.state = CBPeripheralStateConnected;
    [registrar.plugin centralManager:(id)central didConnectPeripheral:(id)peripheral];

    NSCAssert(central.cancellations == 2, @"Late connection was not cancelled again");
    NSCAssert([Call(registrar.plugin, @"connectedCount") isEqual:@1], @"Late connection escaped teardown");
    NSCAssert([[registrar.plugin valueForKey:@"currentlyConnectingPeripherals"] count] == 0, @"Pending entry was not moved");
    NSCAssert([[registrar.plugin valueForKey:@"connectedPeripherals"] count] == 1, @"Connected entry was not retained");
    NSCAssert(registrar.messenger.events.count == 0, @"Old connection event reached Dart");
    FinishRestart(registrar, peripheral);
    NSCAssert(registrar.messenger.events.count == 0, @"Old teardown event reached Dart");
}

static void TestRepeatedRestartRetainsPendingConnection(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePendingPlugin(&peripheral);
    TestCentralManager *central = [registrar.plugin valueForKey:@"centralManager"];
    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"First restart did not count pending connection");

    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Second restart lost pending connection");
    NSCAssert(central.cancellations == 2, @"Second restart did not request cancellation");
    FinishRestart(registrar, peripheral);
    NSCAssert(registrar.messenger.events.count == 0, @"Repeated restart leaked teardown events");
}

static void TestPendingAndConnectedPeripheralIsCountedOnce(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    NSMutableDictionary *pending = [registrar.plugin valueForKey:@"currentlyConnectingPeripherals"];
    pending[peripheral.identifier.UUIDString] = peripheral;
    NSCAssert(pending.count == 1 && [[registrar.plugin valueForKey:@"connectedPeripherals"] count] == 1,
              @"Overlapping connection-map setup failed");

    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Peripheral was counted twice");
    TestCentralManager *central = [registrar.plugin valueForKey:@"centralManager"];
    NSCAssert(central.cancellations == 1, @"Peripheral was cancelled twice");
    FinishRestart(registrar, peripheral);
    NSCAssert(pending.count == 0, @"Pending entry survived terminal disconnect");
}

static void TestStalledTeardownEndsAtDeadline(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    peripheral.delegate = plugin;
    NSCAssert([Call(plugin, @"flutterRestart") isEqual:@1], @"Restart did not begin");
    NSCAssert([Call(plugin, @"connectedCount") isEqual:@1], @"Teardown ended before its deadline");

    // CoreBluetooth never reports the disconnect; let the deadline pass.
    [plugin setValue:[NSDate distantPast] forKey:@"flutterRestartDeadline"];

    NSCAssert([Call(plugin, @"connectedCount") isEqual:@0], @"Stalled teardown blocked the new isolate");
    NSCAssert(![[plugin valueForKey:@"flutterRestarting"] boolValue], @"Restart flag stayed set");
    NSCAssert([[plugin valueForKey:@"connectedPeripherals"] count] == 0, @"Old connection stayed registered");
    NSCAssert(peripheral.delegate == nil, @"Old peripheral kept its delegate");
    [plugin peripheralDidUpdateName:(id)peripheral];
    NSArray *methods = [registrar.messenger.events valueForKey:@"method"];
    NSCAssert(methods.count == 0, @"Retired peripheral reached the replacement session: %@", methods);
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestRetriedRestartKeepsDeadline(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    Call(registrar.plugin, @"flutterRestart");
    NSDate *deadline = [registrar.plugin valueForKey:@"flutterRestartDeadline"];
    NSCAssert(deadline != nil, @"Restart has no deadline");

    Call(registrar.plugin, @"flutterRestart");

    NSCAssert([registrar.plugin valueForKey:@"flutterRestartDeadline"] == deadline, @"Retry extended the deadline");
    FinishRestart(registrar, peripheral);
    NSCAssert([registrar.plugin valueForKey:@"flutterRestartDeadline"] == nil, @"Finished restart kept its deadline");
}

// A listen in flight: its manager still waits for didPublishL2CAPChannel.
static TestPeripheralManager *AddPendingListener(id l2cap, NSMutableArray *results) {
    TestPeripheralManager *pending = [TestPeripheralManager new];
    NSMutableDictionary *managers = [l2cap valueForKey:@"peripheralManagers"];
    managers[@0] = pending;
    [l2cap setValue:^(id value) { [results addObject:value]; } forKey:@"pendingListenResult"];
    return pending;
}

static void TestRestartRetiresListeners(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    id<RestartTestPeripheralManagerDelegate> l2cap = [registrar.plugin valueForKey:@"l2CapChannelManager"];
    TestPeripheralManager *published = [TestPeripheralManager new];
    NSMutableDictionary *managers = [(id)l2cap valueForKey:@"peripheralManagers"];
    managers[@0x81] = published;
    NSMutableArray *listenResults = [NSMutableArray new];
    TestPeripheralManager *pending = AddPendingListener(l2cap, listenResults);

    NSCAssert([Call(registrar.plugin, @"flutterRestart") isEqual:@1], @"Restart did not begin");

    NSCAssert([published.unpublished isEqual:@[@0x81]], @"Old listener stayed published: %@", published.unpublished);
    NSCAssert(managers.count == 0, @"Old listeners stayed registered");
    NSCAssert(listenResults.count == 1 && [listenResults[0] isKindOfClass:[FlutterError class]],
              @"Pending listen was not failed: %@", listenResults);
    [l2cap peripheralManager:(id)pending didPublishL2CAPChannel:0x82 error:nil];
    [l2cap peripheralManager:(id)published didUnpublishL2CAPChannel:0x81 error:nil];
    NSCAssert([pending.unpublished isEqual:@[@0x82]], @"Late publication stayed published: %@", pending.unpublished);
    NSCAssert(managers.count == 0, @"Late publication was registered");
    NSCAssert(listenResults.count == 1, @"Late publication completed the old listen");
    NSCAssert(registrar.messenger.events.count == 0, @"Old listener events reached Dart");
    FinishRestart(registrar, peripheral);
}

static void TestRetiredListenerCannotServeNewListen(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    id<RestartTestPeripheralManagerDelegate> l2cap = [registrar.plugin valueForKey:@"l2CapChannelManager"];
    TestPeripheralManager *old = AddPendingListener(l2cap, [NSMutableArray new]);
    Call(registrar.plugin, @"flutterRestart");
    FinishRestart(registrar, peripheral);
    NSMutableArray *listenResults = [NSMutableArray new];
    TestPeripheralManager *current = AddPendingListener(l2cap, listenResults);

    // Even after cleanup released its strong retirement record, this old
    // producer cannot acquire authority over the replacement listen.
    [l2cap peripheralManager:(id)old didUnpublishL2CAPChannel:0x82 error:nil];
    [l2cap peripheralManager:(id)old didPublishL2CAPChannel:0x82 error:nil];
    [l2cap peripheralManager:(id)old didUnpublishL2CAPChannel:0x82 error:nil];
    NSCAssert(listenResults.count == 0, @"Old publish completed new listen");
    NSCAssert([old.unpublished isEqual:@[@0x82]], @"Unowned publication was not retired");
    [l2cap peripheralManagerDidUpdateState:(id)old];
    [l2cap peripheralManagerDidUpdateState:(id)current];
    [l2cap peripheralManager:(id)current didPublishL2CAPChannel:0x83 error:nil];

    NSCAssert(old.publishRequests == 0, @"Retired manager published for the new isolate");
    NSCAssert(current.publishRequests == 1, @"New listener did not publish");
    NSCAssert([listenResults isEqual:@[@{@"psm": @0x83}]], @"New listen result missing: %@", listenResults);
    NSArray *methods = [registrar.messenger.events valueForKey:@"method"];
    NSCAssert([methods isEqual:@[@"OnL2CapChannelPublished"]], @"New listener events missing: %@", methods);
}

static void TestOldManagerCannotMutateReplacement(void) {
    TestPeripheral *old;
    TestRegistrar *registrar = CreatePlugin(&old);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    id oldCentral = [plugin valueForKey:@"centralManager"];
    Call(plugin, @"flutterRestart");
    [plugin setValue:[NSDate distantPast] forKey:@"flutterRestartDeadline"];
    NSCAssert([Call(plugin, @"connectedCount") isEqual:@0], @"Deadline did not finish");
    id currentCentral = [plugin valueForKey:@"centralManager"];
    NSCAssert(currentCentral != oldCentral, @"Native session was reused");
    TestPeripheral *replacement = [TestPeripheral new];
    replacement.identifier = old.identifier;
    replacement.state = CBPeripheralStateConnecting;
    replacement.services = @[];
    NSMutableDictionary *pending = [plugin valueForKey:@"currentlyConnectingPeripherals"];
    pending[replacement.identifier.UUIDString] = replacement;
    [registrar.messenger.events removeAllObjects];

    [plugin centralManager:oldCentral didConnectPeripheral:(id)old];
    [plugin centralManager:oldCentral didDisconnectPeripheral:(id)old error:nil];
    [plugin centralManager:oldCentral didFailToConnectPeripheral:(id)old error:nil];
    [plugin centralManagerDidUpdateState:oldCentral];
    NSCAssert(pending[replacement.identifier.UUIDString] == replacement, @"Old callback removed replacement");
    NSCAssert([[plugin valueForKey:@"connectedPeripherals"] count] == 0, @"Old connection adopted");
    NSCAssert(registrar.messenger.events.count == 0, @"Old manager emitted events");

    replacement.state = CBPeripheralStateConnected;
    [plugin centralManager:currentCentral didConnectPeripheral:(id)replacement];
    NSCAssert([[plugin valueForKey:@"connectedPeripherals"] objectForKey:replacement.identifier.UUIDString] == replacement,
              @"Replacement connection was rejected");
    [plugin peripheral:(id)replacement didReadRSSI:@(-50) error:nil];
    NSCAssert(registrar.messenger.events.count == 2, @"New session events missing");
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestEmptyRestartStillRetiresItsProducer(void) {
    TestPeripheral *old;
    TestRegistrar *registrar = CreatePlugin(&old);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    id oldCentral = [plugin valueForKey:@"centralManager"];
    [[plugin valueForKey:@"connectedPeripherals"] removeAllObjects];
    NSCAssert([Call(plugin, @"flutterRestart") isEqual:@0], @"Empty restart blocked");
    NSCAssert([plugin valueForKey:@"centralManager"] != oldCentral, @"Empty restart reused producer");
    [plugin centralManager:oldCentral didConnectPeripheral:(id)old];
    NSCAssert([[plugin valueForKey:@"connectedPeripherals"] count] == 0, @"Old connection adopted");
    NSCAssert(registrar.messenger.events.count == 0, @"Old session emitted event");
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static TestChannel *NewChannel(void) {
    TestChannel *channel = [TestChannel new];
    channel.PSM = 0x81;
    channel.inputStream = [NSInputStream inputStreamWithData:[NSData data]];
    channel.outputStream = [NSOutputStream outputStreamToMemory];
    return channel;
}

static void TestLateClientOpenCannotReviveChannel(void) {
    TestPeripheral *old;
    TestRegistrar *registrar = CreatePlugin(&old);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    id manager = [plugin valueForKey:@"l2CapChannelManager"];
    Call(plugin, @"flutterRestart");
    for (NSUInteger phase = 0; phase < 2; phase++) {
        TestChannel *channel = NewChannel();
        [plugin peripheral:(id)old didOpenL2CAPChannel:(id)channel error:nil];
        NSCAssert([[manager valueForKey:@"channels"] count] == 0, @"Retired open adopted");
        NSCAssert([[manager valueForKey:@"pendingStreamReady"] count] == 0, @"Retired readiness installed");
        NSCAssert(registrar.messenger.events.count == 0, @"Retired open emitted event");
        [plugin setValue:[NSDate distantPast] forKey:@"flutterRestartDeadline"];
        Call(plugin, @"connectedCount");
    }
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestQueuedStreamSetupCannotOutliveCleanup(void) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    id manager = [plugin valueForKey:@"l2CapChannelManager"];
    TestChannel *channel = NewChannel();
    [plugin peripheral:(id)peripheral didOpenL2CAPChannel:(id)channel error:nil];
    NSCAssert([[manager valueForKey:@"channels"] count] == 1, @"Active open not adopted");
    Call(plugin, @"flutterRestart");
    // Drain the real main queue after cleanup, including the queued setup block.
    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    while (!drained) [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    NSCAssert(channel.inputStream.delegate == nil && channel.outputStream.delegate == nil, @"Retired streams rescheduled");
    NSCAssert([[manager valueForKey:@"channels"] count] == 0, @"Channel survived cleanup");
    NSCAssert(registrar.messenger.events.count == 0, @"Retired stream emitted event");
    FinishRestart(registrar, peripheral);
}

static id CallWithArguments(FlutterBlueMaxPlugin *plugin, NSString *method, id arguments) {
    __block id response = nil;
    [plugin handleMethodCall:[FlutterMethodCall methodCallWithMethodName:method arguments:arguments]
                      result:^(id value) { response = value; }];
    NSCAssert(![response isKindOfClass:[FlutterError class]], @"Unexpected error: %@", response);
    return response;
}

static void TestCancelPendingConnect(BOOL failsToConnect, BOOL connectsWhileCancelling) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    FlutterBlueMaxPlugin *plugin = registrar.plugin;
    TestCentralManager *central = [plugin valueForKey:@"centralManager"];
    central.retrievedPeripheral = peripheral;
    [[plugin valueForKey:@"connectedPeripherals"] removeAllObjects];
    NSCAssert([CallWithArguments(plugin, @"connect", @{@"remote_id": peripheral.identifier.UUIDString,
                                                      @"auto_connect": @NO}) isEqual:@YES], @"Connect did not start");
    NSCAssert(central.connectRequests == 1 && peripheral.state == CBPeripheralStateConnecting, @"No native connect pending");
    NSCAssert([CallWithArguments(plugin, @"disconnect", peripheral.identifier.UUIDString) isEqual:@YES], @"Disconnect did not cancel");
    NSCAssert(central.cancellations == 1, @"Native cancellation missing");
    if (connectsWhileCancelling) {
        peripheral.state = CBPeripheralStateConnected;
        [plugin centralManager:(id)central didConnectPeripheral:(id)peripheral];
        NSCAssert(registrar.messenger.events.count == 0, @"Cancelled attempt emitted connected");
        NSCAssert(central.cancellations == 2, @"Late connection was not cancelled again");
    }
    peripheral.state = CBPeripheralStateDisconnected;
    if (failsToConnect) {
        NSError *cancelled = [NSError errorWithDomain:CBErrorDomain code:CBErrorOperationCancelled userInfo:nil];
        [plugin centralManager:(id)central didFailToConnectPeripheral:(id)peripheral error:cancelled];
    } else {
        [plugin centralManager:(id)central didDisconnectPeripheral:(id)peripheral error:nil];
    }
    NSCAssert(registrar.messenger.events.count == 1, @"Dart never received cancellation");
    FlutterMethodCall *event = registrar.messenger.events.lastObject;
    NSCAssert([event.method isEqual:@"OnConnectionStateChanged"], @"Wrong event");
    NSCAssert([event.arguments[@"connection_state"] isEqual:@0], @"Cancellation not disconnected");
    NSCAssert([event.arguments[@"disconnect_reason_code"] isEqual:@23789258], @"Missing connectionCanceled reason");
    NSCAssert([[plugin valueForKey:@"currentlyConnectingPeripherals"] count] == 0, @"Pending attempt retained after terminal event");
    NSCAssert([CallWithArguments(plugin, @"disconnect", peripheral.identifier.UUIDString) isEqual:@NO], @"Completed cancel still pending");
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

static void TestRestartWaitsForManagerReadiness(CBManagerState finalState) {
    TestPeripheral *peripheral;
    TestRegistrar *registrar = CreatePlugin(&peripheral);
    TestPlugin *plugin = (id)registrar.plugin;
    plugin.delayManagerReadiness = YES;
    id oldCentral = [plugin valueForKey:@"centralManager"];
    Call(plugin, @"flutterRestart");
    [plugin setValue:[NSDate distantPast] forKey:@"flutterRestartDeadline"];
    NSCAssert([Call(plugin, @"connectedCount") isEqual:@1], @"Restart completed with an unknown manager");
    TestCentralManager *current = [plugin valueForKey:@"centralManager"];
    NSCAssert(current != oldCentral && current.state == CBManagerStateUnknown, @"Replacement manager missing");
    current.state = CBManagerStateResetting;
    NSCAssert([Call(plugin, @"connectedCount") isEqual:@1], @"Restart completed while manager resetting");
    NSCAssert([Call(plugin, @"flutterRestart") isEqual:@1], @"Retry bypassed readiness");
    NSCAssert([plugin valueForKey:@"centralManager"] == current, @"Retry replaced initializing manager");
    current.state = finalState;
    [plugin centralManagerDidUpdateState:(id)current];
    NSCAssert([Call(plugin, @"connectedCount") isEqual:@0], @"Known adapter state blocked restart");
    NSCAssert([plugin valueForKey:@"centralManager"] == current, @"Ready manager replaced again");
    if (finalState == CBManagerStatePoweredOn) {
        NSCAssert([CallWithArguments(plugin, @"startScan", @{@"with_services": @[]}) isEqual:@YES], @"Immediate scan failed");
        NSCAssert(current.scanRequests == 1, @"Scan never reached ready manager");
    }
    [[plugin valueForKey:@"checkForMtuChangesTimer"] invalidate];
}

int main(void) {
    @autoreleasepool {
        TestCancelPendingConnect(NO, NO);
        TestCancelPendingConnect(YES, NO);
        TestCancelPendingConnect(NO, YES);
        TestRestartWaitsForManagerReadiness(CBManagerStatePoweredOn);
        TestRestartWaitsForManagerReadiness(CBManagerStatePoweredOff);
        TestMtuTimerDuringRestart();
        TestPeripheralCallbacksDuringRestart();
        TestNewSessionEvents();
        TestPendingConnectionTeardown();
        TestPendingConnectionCompletesDuringRestart();
        TestRepeatedRestartRetainsPendingConnection();
        TestPendingAndConnectedPeripheralIsCountedOnce();
        TestRestartRetiresListeners();
        TestRetiredListenerCannotServeNewListen();
        TestStalledTeardownEndsAtDeadline();
        TestRetriedRestartKeepsDeadline();
        TestOldManagerCannotMutateReplacement();
        TestLateClientOpenCannotReviveChannel();
        TestQueuedStreamSetupCannotOutliveCleanup();
        TestEmptyRestartStillRetiresItsProducer();
        puts("20 Darwin restart regression tests passed");
    }
    return 0;
}
