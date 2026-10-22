#import "FlutterBlueMaxPlugin.h"

// Exercise the real plugin; only the CoreBluetooth/Flutter boundaries are faked.
@interface FlutterBlueMaxPlugin (RestartTests)
- (void)checkForMtuChangesCallback;
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
@end

@implementation TestCentralManager
- (CBManagerState)state {
    return CBManagerStatePoweredOn;
}
- (void)stopScan {}
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    self.cancellations++;
}
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
    [FlutterBlueMaxPlugin registerWithRegistrar:(id)registrar];
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

int main(void) {
    @autoreleasepool {
        TestMtuTimerDuringRestart();
        TestPeripheralCallbacksDuringRestart();
        TestNewSessionEvents();
        TestPendingConnectionTeardown();
        TestPendingConnectionCompletesDuringRestart();
        TestRepeatedRestartRetainsPendingConnection();
        TestPendingAndConnectedPeripheralIsCountedOnce();
        puts("7 Darwin restart regression tests passed");
    }
    return 0;
}
