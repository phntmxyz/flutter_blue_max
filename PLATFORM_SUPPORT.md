# Platform support

- ✅ supported: works as documented.
- ⚠️ limited: works with a restriction, see the numbered note below the table.
- ❌ unsupported: the platform cannot do it, see the numbered note for what you get instead.
- 🚧 not implemented: the platform could do it, the library does not yet, see the numbered note.

| Platform | Supported | Limited | Not implemented | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| Android | 75 | 9 | 1 | 2 |
| iOS | 60 | 8 | 1 | 18 |
| macOS | 61 | 7 | 1 | 18 |
| Linux | 42 | 13 | 23 | 9 |
| Web | 21 | 17 | 7 | 42 |

## Adapter

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Ask whether the device supports Bluetooth | `FlutterBlueMax.isSupported` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Read and follow the state of the Bluetooth adapter | `FlutterBlueMax.adapterState`, `FlutterBlueMax.adapterStateNow` | ✅ | ✅ | ✅ | ✅ | ⚠️ [1] |
| Read the name of the Bluetooth adapter | `FlutterBlueMax.adapterName` | ✅ | ⚠️ [2] | ✅ | ✅ | ❌ [3] |
| Turn the Bluetooth adapter on | `FlutterBlueMax.turnOn` | ✅ | ❌ [4] | ❌ [4] | ✅ | ❌ [5] |
| Turn the Bluetooth adapter off | `FlutterBlueMax.turnOff` | ⚠️ [6] | ❌ [7] | ❌ [7] | ✅ | ❌ [8] |
| Set the power alert and state restoration of CoreBluetooth | `FlutterBlueMax.setOptions` | ❌ [9] | ✅ | ✅ | ❌ [9] | ❌ [9] |

1. **Read and follow the state of the Bluetooth adapter** (Web): The browser reports no adapter state changes, the state is on when Web Bluetooth is available and never changes.
2. **Read the name of the Bluetooth adapter** (iOS): CoreBluetooth has no adapter name, the name of the device is returned.
3. **Read the name of the Bluetooth adapter** (Web): Web Bluetooth has no adapter name, an empty string is returned.
4. **Turn the Bluetooth adapter on** (iOS, macOS): iOS and macOS do not let an app switch Bluetooth on, turnOn throws androidOnly.
5. **Turn the Bluetooth adapter on** (Web): The browser cannot switch the adapter, turnOn returns without doing anything.
6. **Turn the Bluetooth adapter off** (Android): Deprecated since Android 13, where the system refuses and turnOff returns without switching the adapter off.
7. **Turn the Bluetooth adapter off** (iOS, macOS): iOS and macOS do not let an app switch Bluetooth off, turnOff returns without doing anything.
8. **Turn the Bluetooth adapter off** (Web): The browser cannot switch the adapter, turnOff returns without doing anything.
9. **Set the power alert and state restoration of CoreBluetooth** (Android, Linux, Web): The options exist on iOS and macOS only, setOptions has no effect.

## Scanning

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Start and stop a scan and follow its results | `FlutterBlueMax.startScan`, `FlutterBlueMax.stopScan`, `FlutterBlueMax.isScanning`, `FlutterBlueMax.scanResults`, `FlutterBlueMax.onScanResults`, `FlutterBlueMax.lastScanResults`, `FlutterBlueMax.cancelWhenScanComplete` | ✅ | ✅ | ✅ | ✅ | ⚠️ [1] |
| End a scan on its own after a timeout | `FlutterBlueMax.startScan(timeout)` | ✅ | ✅ | ✅ | ✅ | ⚠️ [2] |
| Only report devices that advertise given services | `FlutterBlueMax.startScan(withServices)` | ✅ | ✅ | ✅ | ✅ | ⚠️ [3] |
| Only report devices with an exact advertised name | `FlutterBlueMax.startScan(withNames)` | ✅ | ✅ | ✅ | 🚧 [4] | ⚠️ [5] |
| Only report devices with given remote ids | `FlutterBlueMax.startScan(withRemoteIds)` | ✅ | ✅ | ✅ | 🚧 [6] | ❌ [7] |
| Only report devices whose advertised name contains a keyword | `FlutterBlueMax.startScan(withKeywords)` | ⚠️ [8] | ✅ | ✅ | 🚧 [9] | ❌ [10] |
| Only report devices with matching manufacturer data | `FlutterBlueMax.startScan(withMsd)`, `MsdFilter` | ✅ | ✅ | ✅ | 🚧 [11] | ⚠️ [12] |
| Only report devices with matching service data | `FlutterBlueMax.startScan(withServiceData)`, `ServiceDataFilter` | ✅ | ✅ | ✅ | 🚧 [13] | ⚠️ [14] |
| Report repeated advertisements of a device to update its RSSI and data | `FlutterBlueMax.startScan(continuousUpdates)`, `FlutterBlueMax.startScan(continuousDivisor)` | ✅ | ✅ | ✅ | 🚧 [15] | ❌ [16] |
| Remove devices from the results when they stop advertising | `FlutterBlueMax.startScan(removeIfGone)` | ✅ | ✅ | ✅ | 🚧 [17] | ❌ [18] |
| Report every advertisement as a list with a single result | `FlutterBlueMax.startScan(oneByOne)` | ✅ | ✅ | ✅ | ⚠️ [19] | ❌ [20] |
| Choose the Android scan mode, legacy scanning and the location permission | `FlutterBlueMax.startScan(androidLegacy)`, `FlutterBlueMax.startScan(androidScanMode)`, `FlutterBlueMax.startScan(androidUsesFineLocation)`, `FlutterBlueMax.startScan(androidCheckLocationServices)` | ✅ | ❌ [21] | ❌ [21] | ❌ [21] | ❌ [21] |
| Name the optional services the browser may access | `FlutterBlueMax.startScan(webOptionalServices)` | ❌ [22] | ❌ [22] | ❌ [22] | ❌ [22] | ✅ |
| Read the advertised name of a device | `AdvertisementData.advName`, `BluetoothDevice.advName`, `BluetoothDevice.platformName` | ✅ | ✅ | ✅ | ⚠️ [23] | ⚠️ [24] |
| Read the service UUIDs, manufacturer data, service data, TX power and connectable flag of an advertisement | `AdvertisementData.serviceUuids`, `AdvertisementData.manufacturerData`, `AdvertisementData.serviceData`, `AdvertisementData.txPowerLevel`, `AdvertisementData.connectable` | ✅ | ✅ | ✅ | ⚠️ [25] | ❌ [26] |
| Read the appearance of an advertisement | `AdvertisementData.appearance` | ✅ | ❌ [27] | ❌ [27] | ✅ | ❌ [28] |
| Read the RSSI of a scan result | `ScanResult.rssi` | ✅ | ✅ | ✅ | ✅ | ❌ [29] |
| Receive extended advertisements with more than 31 bytes of data | `FlutterBlueMax.startScan`, `AdvertisementData.manufacturerData` | ⚠️ [30] | ⚠️ [31] | ⚠️ [31] | ✅ | ❌ [32] |
| Identify a device by its Bluetooth address | `BluetoothDevice.remoteId` | ✅ | ❌ [33] | ❌ [33] | ✅ | ❌ [34] |

1. **Start and stop a scan and follow its results** (Web): startScan opens the device chooser of the browser and reports the one device that is picked, no scan keeps running.
2. **End a scan on its own after a timeout** (Web): The timeout only ends the isScanning flag, there is no running scan to end.
3. **Only report devices that advertise given services** (Web): The filter becomes a filter of the browser chooser, which then offers matching devices.
4. **Only report devices with an exact advertised name** (Linux): BlueZ only filters discovery by service UUID, the filter is ignored and every device is reported.
5. **Only report devices with an exact advertised name** (Web): The filter becomes an exact-name filter of the browser chooser.
6. **Only report devices with given remote ids** (Linux): BlueZ only filters discovery by service UUID, the filter is ignored and every device is reported.
7. **Only report devices with given remote ids** (Web): The browser chooser cannot filter by device id, the filter is ignored.
8. **Only report devices whose advertised name contains a keyword** (Android): Cannot be combined with other filters, the library matches the keywords itself and the system does not.
9. **Only report devices whose advertised name contains a keyword** (Linux): BlueZ only filters discovery by service UUID, the filter is ignored and every device is reported.
10. **Only report devices whose advertised name contains a keyword** (Web): Web Bluetooth only filters by name prefix, the keywords are ignored.
11. **Only report devices with matching manufacturer data** (Linux): BlueZ only filters discovery by service UUID, the filter is ignored and every device is reported.
12. **Only report devices with matching manufacturer data** (Web): The chooser filters by company id only, the data and the mask of the filter are ignored.
13. **Only report devices with matching service data** (Linux): BlueZ only filters discovery by service UUID, the filter is ignored and every device is reported.
14. **Only report devices with matching service data** (Web): The chooser filters by service UUID only, the data and the mask of the filter are ignored.
15. **Report repeated advertisements of a device to update its RSSI and data** (Linux): BlueZ results are reported once per device, repeated advertisements are not.
16. **Report repeated advertisements of a device to update its RSSI and data** (Web): The chooser returns a device once, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
17. **Remove devices from the results when they stop advertising** (Linux): Without repeated advertisements every device looks gone and is removed after the timeout.
18. **Remove devices from the results when they stop advertising** (Web): The chooser returns a device once, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
19. **Report every advertisement as a list with a single result** (Linux): Every result is reported on its own, but BlueZ reports each device only once.
20. **Report every advertisement as a list with a single result** (Web): The chooser of the browser returns one device per scan, there is no stream of advertisements to deliver one by one.
21. **Choose the Android scan mode, legacy scanning and the location permission** (iOS, macOS, Linux, Web): The options exist on Android only and are ignored.
22. **Name the optional services the browser may access** (Android, iOS, macOS, Linux): The option exists on the web only and is ignored.
23. **Read the advertised name of a device** (Linux): advName stays empty, platformName holds the name BlueZ cached.
24. **Read the advertised name of a device** (Web): platformName is the name the browser shows, advName is always empty.
25. **Read the service UUIDs, manufacturer data, service data, TX power and connectable flag of an advertisement** (Linux): connectable is always true, BlueZ does not report it.
26. **Read the service UUIDs, manufacturer data, service data, TX power and connectable flag of an advertisement** (Web): The chooser returns name and id only, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
27. **Read the appearance of an advertisement** (iOS, macOS): CoreBluetooth does not expose the appearance, it is null.
28. **Read the appearance of an advertisement** (Web): The chooser returns name and id only, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
29. **Read the RSSI of a scan result** (Web): The chooser reports no signal strength so rssi is 0, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
30. **Receive extended advertisements with more than 31 bytes of data** (Android): Needs Android 8 (API 26) and a Bluetooth controller that scans extended advertising.
31. **Receive extended advertisements with more than 31 bytes of data** (iOS, macOS): CoreBluetooth decides which extended advertisements it delivers, the library cannot ask for them.
32. **Receive extended advertisements with more than 31 bytes of data** (Web): The chooser returns name and id only, and Chrome only offers watchAdvertisements() behind the experimental web platform features flag, which the library does not use.
33. **Identify a device by its Bluetooth address** (iOS, macOS): CoreBluetooth hides the address, remoteId is a UUID that the system picks for the device.
34. **Identify a device by its Bluetooth address** (Web): The browser hides the address, remoteId is an opaque id of the chooser.

## Connection

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Connect to a device, disconnect and follow the connection state | `BluetoothDevice.connect`, `BluetoothDevice.disconnect`, `BluetoothDevice.isConnected`, `BluetoothDevice.connectionState`, `BluetoothDevice.cancelWhenDisconnected` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Give up connecting after a timeout | `BluetoothDevice.connect(timeout)` | ✅ | ✅ | ✅ | 🚧 [1] | 🚧 [1] |
| Cancel a pending connect | `BluetoothDevice.disconnect(queue)` | ✅ | ✅ | ✅ | 🚧 [2] | 🚧 [2] |
| Connect whenever the device is in range and reconnect after a lost link | `BluetoothDevice.connect(autoConnect)`, `BluetoothDevice.isAutoConnectEnabled` | ✅ | ✅ | ✅ | ⚠️ [3] | 🚧 [4] |
| Report that the device ended the connection | `BluetoothDevice.connectionState`, `BluetoothDevice.isConnected` | ✅ | ✅ | ✅ | ✅ | 🚧 [5] |
| Tell why a connection ended | `BluetoothDevice.disconnectReason` | ✅ | ✅ | ✅ | ❌ [6] | ❌ [7] |
| List the devices connected to the app | `FlutterBlueMax.connectedDevices` | ✅ | ✅ | ✅ | ✅ | ✅ |
| List the devices connected to the system, also by other apps | `FlutterBlueMax.systemDevices` | ✅ | ⚠️ [8] | ⚠️ [8] | ⚠️ [9] | ❌ [10] |
| Connect to several devices at the same time | `BluetoothDevice.connect`, `FlutterBlueMax.connectedDevices` | ✅ | ✅ | ✅ | ✅ | ⚠️ [11] |

1. **Give up connecting after a timeout** (Linux, Web): The platform connect blocks inside the platform call, so connect never fails with a timeout.
2. **Cancel a pending connect** (Linux, Web): A pending connect holds the locks, so disconnect(queue: false) cannot interrupt it and the connect is not canceled.
3. **Connect whenever the device is in range and reconnect after a lost link** (Linux): The first connect fails while the device is absent, after a lost link the library reconnects on its own.
4. **Connect whenever the device is in range and reconnect after a lost link** (Web): autoConnect is ignored, the library does not reconnect after a lost link.
5. **Report that the device ended the connection** (Web): The library does not listen to gattserverdisconnected, so the connection state stays connected after the device ended the connection.
6. **Tell why a connection ended** (Linux): BlueZ does not report why a link ended, disconnectReason has no code and no description.
7. **Tell why a connection ended** (Web): The browser does not report why a link ended, disconnectReason has no code and no description.
8. **List the devices connected to the system, also by other apps** (iOS, macOS): Only devices that offer one of the given services are listed.
9. **List the devices connected to the system, also by other apps** (Linux): Every device BlueZ knows is listed, connected or not, the services are ignored.
10. **List the devices connected to the system, also by other apps** (Web): Web Bluetooth has no such list, an empty list is returned.
11. **Connect to several devices at the same time** (Web): The browser chooser has to be answered once for every device.

## Service discovery

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Discover the services and characteristics of a connected device | `BluetoothDevice.discoverServices`, `BluetoothDevice.servicesList`, `BluetoothService.characteristics` | ✅ | ✅ | ✅ | ✅ | ⚠️ [1] |
| Read the properties of a characteristic | `BluetoothCharacteristic.properties`, `CharacteristicProperties` | ✅ | ✅ | ✅ | ⚠️ [2] | ⚠️ [3] |
| Discover the descriptors of a characteristic | `BluetoothCharacteristic.descriptors` | ✅ | ✅ | ✅ | ✅ | ⚠️ [4] |
| Discover secondary services and the services a service includes | `BluetoothService.includedServices`, `BluetoothService.isSecondary`, `BluetoothService.primaryService` | ✅ | 🚧 [5] | 🚧 [5] | 🚧 [6] | ❌ [7] |
| Notice that the services of a device changed | `BluetoothDevice.onServicesReset`, `BluetoothDevice.discoverServices(subscribeToServicesChanged)` | ✅ | ✅ | ✅ | ⚠️ [8] | ❌ [9] |
| Clear the cache of discovered services | `BluetoothDevice.clearGattCache` | ⚠️ [10] | ❌ [11] | ❌ [11] | 🚧 [12] | ❌ [13] |

1. **Discover the services and characteristics of a connected device** (Web): Only services named in a filter or in webOptionalServices can be discovered.
2. **Read the properties of a characteristic** (Linux): notifyEncryptionRequired and indicateEncryptionRequired are always false.
3. **Read the properties of a characteristic** (Web): extendedProperties and the encryption flags are always false.
4. **Discover the descriptors of a characteristic** (Web): Descriptors the browser blocks or fails to list are left out.
5. **Discover secondary services and the services a service includes** (iOS, macOS): The plugin discovers included services but does not pass them on, includedServices is empty and isSecondary is false.
6. **Discover secondary services and the services a service includes** (Linux): Secondary services are not listed, primaryServiceUuid is always null.
7. **Discover secondary services and the services a service includes** (Web): Web Bluetooth lists primary services only.
8. **Notice that the services of a device changed** (Linux): Approximated by a change of the UUIDs property that BlueZ keeps for the device.
9. **Notice that the services of a device changed** (Web): The browser reports no service changes, onServicesReset never emits.
10. **Clear the cache of discovered services** (Android): Uses the hidden BluetoothGatt.refresh() through reflection, which a vendor or a later Android version may block.
11. **Clear the cache of discovered services** (iOS, macOS): CoreBluetooth manages its cache itself, clearGattCache throws androidOnly.
12. **Clear the cache of discovered services** (Linux): clearGattCache throws androidOnly, although BlueZ can forget a device together with its cache.
13. **Clear the cache of discovered services** (Web): The browser has no such call, clearGattCache throws androidOnly.

## Reading and writing

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Read a characteristic | `BluetoothCharacteristic.read` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write a characteristic with response | `BluetoothCharacteristic.write` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write a characteristic without response | `BluetoothCharacteristic.write(withoutResponse)` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write a value longer than the MTU with a long write | `BluetoothCharacteristic.write(allowLongWrite)` | ✅ | ✅ | ✅ | ⚠️ [1] | ⚠️ [2] |
| Keep and stream the latest value of a characteristic | `BluetoothCharacteristic.lastValue`, `BluetoothCharacteristic.lastValueStream`, `BluetoothCharacteristic.onValueReceived` | ✅ | ✅ | ✅ | ✅ | ✅ |

1. **Write a value longer than the MTU with a long write** (Linux): allowLongWrite is ignored, BlueZ decides how to split a long write.
2. **Write a value longer than the MTU with a long write** (Web): allowLongWrite is ignored, the browser decides how to split a long write.

## Notifications and indications

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Subscribe to notifications of a characteristic | `BluetoothCharacteristic.setNotifyValue`, `BluetoothCharacteristic.onValueReceived` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Subscribe to indications of a characteristic | `BluetoothCharacteristic.setNotifyValue`, `BluetoothCharacteristic.onValueReceived` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Subscribe with indications although the characteristic can notify | `BluetoothCharacteristic.setNotifyValue(forceIndications)` | ✅ | ❌ [1] | ❌ [1] | ❌ [1] | ❌ [1] |
| Tell whether a characteristic is subscribed | `BluetoothCharacteristic.isNotifying` | ✅ | ✅ | ✅ | 🚧 [2] | 🚧 [2] |

1. **Subscribe with indications although the characteristic can notify** (iOS, macOS, Linux, Web): Only Android can force indications, the flag trips an assert in debug builds and is ignored otherwise.
2. **Tell whether a characteristic is subscribed** (Linux, Web): No CCCD write is reported, so isNotifying stays false after a successful subscription.

## Descriptors

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Read a descriptor | `BluetoothDescriptor.read` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write a descriptor | `BluetoothDescriptor.write` | ✅ | ⚠️ [1] | ⚠️ [1] | ⚠️ [2] | ⚠️ [3] |
| Keep and stream the latest value of a descriptor | `BluetoothDescriptor.lastValue`, `BluetoothDescriptor.lastValueStream`, `BluetoothDescriptor.onValueReceived` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Know the value of the CCCD after a subscription | `BluetoothDescriptor.lastValue` | ✅ | ⚠️ [4] | ⚠️ [4] | 🚧 [5] | 🚧 [6] |

1. **Write a descriptor** (iOS, macOS): The CCCD cannot be written directly, CoreBluetooth only changes it through setNotifyValue.
2. **Write a descriptor** (Linux): BlueZ hides the CCCD, it can only be changed through setNotifyValue.
3. **Write a descriptor** (Web): The browser refuses writes to the CCCD, use setNotifyValue instead.
4. **Know the value of the CCCD after a subscription** (iOS, macOS): The value is derived from isNotifying, the CCCD cannot be read from the peer.
5. **Know the value of the CCCD after a subscription** (Linux): The plugin reports no CCCD write, the library never knows the value.
6. **Know the value of the CCCD after a subscription** (Web): The browser keeps the CCCD to itself, the library never knows the value.

## Link

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Read and follow the ATT MTU | `BluetoothDevice.mtuNow`, `BluetoothDevice.mtu` | ✅ | ⚠️ [1] | ⚠️ [1] | 🚧 [2] | ❌ [3] |
| Request a larger ATT MTU | `BluetoothDevice.requestMtu`, `BluetoothDevice.connect(mtu)` | ✅ | ❌ [4] | ❌ [4] | ❌ [5] | ❌ [6] |
| Request a connection priority | `BluetoothDevice.requestConnectionPriority` | ✅ | ❌ [7] | ❌ [7] | ❌ [8] | ❌ [9] |
| Ask which PHYs the adapter supports | `FlutterBlueMax.getPhySupport`, `PhySupport` | ✅ | ❌ [10] | ❌ [10] | ❌ [11] | ❌ [12] |
| Ask for a preferred PHY | `BluetoothDevice.setPreferredPhy` | ⚠️ [13] | ❌ [14] | ❌ [14] | ❌ [15] | ❌ [16] |
| Name PHYs with the bit masks of the Bluetooth specification | `Phy.mask`, `PhyCoding` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Read the RSSI of a connection | `BluetoothDevice.readRssi` | ✅ | ✅ | ✅ | ⚠️ [17] | ❌ [18] |
| Keep working while the peer changes MTU, PHY, connection parameters or data length | `BluetoothDevice.connectionState`, `BluetoothDevice.mtu` | ✅ | ✅ | ✅ | ✅ | ✅ |

1. **Read and follow the ATT MTU** (iOS, macOS): The MTU is derived from the largest write CoreBluetooth accepts, at most 515.
2. **Read and follow the ATT MTU** (Linux): The plugin does not read the MTU of BlueZ, mtuNow stays 23 and the mtu stream never emits.
3. **Read and follow the ATT MTU** (Web): Web Bluetooth does not expose the MTU, mtuNow stays 23.
4. **Request a larger ATT MTU** (iOS, macOS): CoreBluetooth negotiates the MTU itself, requestMtu throws androidOnly.
5. **Request a larger ATT MTU** (Linux): BlueZ negotiates the MTU itself, requestMtu throws androidOnly.
6. **Request a larger ATT MTU** (Web): The browser negotiates the MTU itself, requestMtu throws androidOnly.
7. **Request a connection priority** (iOS, macOS): CoreBluetooth has no API for it, requestConnectionPriority throws androidOnly.
8. **Request a connection priority** (Linux): BlueZ has no API for it, requestConnectionPriority throws androidOnly.
9. **Request a connection priority** (Web): Web Bluetooth has no API for it, requestConnectionPriority throws androidOnly.
10. **Ask which PHYs the adapter supports** (iOS, macOS): CoreBluetooth has no PHY API, getPhySupport throws androidOnly.
11. **Ask which PHYs the adapter supports** (Linux): BlueZ has no PHY API, getPhySupport throws androidOnly.
12. **Ask which PHYs the adapter supports** (Web): Web Bluetooth has no PHY API, getPhySupport throws androidOnly.
13. **Ask for a preferred PHY** (Android): The call returns at once, the library reports neither the PHY that was chosen nor a failure to change it.
14. **Ask for a preferred PHY** (iOS, macOS): CoreBluetooth has no PHY API, setPreferredPhy throws androidOnly.
15. **Ask for a preferred PHY** (Linux): BlueZ has no PHY API, setPreferredPhy throws androidOnly.
16. **Ask for a preferred PHY** (Web): Web Bluetooth has no PHY API, setPreferredPhy throws androidOnly.
17. **Read the RSSI of a connection** (Linux): The RSSI BlueZ saw in its latest advertisement is returned, the connection itself is not read.
18. **Read the RSSI of a connection** (Web): Web Bluetooth cannot read the RSSI of a connection, readRssi times out.

## Bonding

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Create a bond with a device | `BluetoothDevice.createBond` | ✅ | ❌ [1] | ❌ [1] | 🚧 [2] | ❌ [3] |
| Create a bond with a given passkey and no dialog | `BluetoothDevice.createBond(pin)` | ⚠️ [4] | ❌ [5] | ❌ [5] | 🚧 [6] | ❌ [7] |
| Remove the bond with a device | `BluetoothDevice.removeBond` | ⚠️ [8] | ❌ [9] | ❌ [9] | 🚧 [10] | ❌ [11] |
| Read and follow the bond state of a device | `BluetoothDevice.bondState`, `BluetoothDevice.prevBondState` | ✅ | ❌ [12] | ❌ [12] | 🚧 [13] | ❌ [14] |
| List the bonded devices | `FlutterBlueMax.bondedDevices` | ✅ | ❌ [15] | ❌ [15] | ✅ | ❌ [16] |

1. **Create a bond with a device** (iOS, macOS): CoreBluetooth has no pairing API, the system pairs when an encrypted characteristic is accessed, createBond throws androidOnly.
2. **Create a bond with a device** (Linux): The plugin can pair through BlueZ, but the library throws androidOnly before it calls the plugin.
3. **Create a bond with a device** (Web): The browser has no pairing API, createBond throws androidOnly.
4. **Create a bond with a given passkey and no dialog** (Android): The PIN is entered for the user, but the pairing dialog of the system is not suppressed and can show up briefly.
5. **Create a bond with a given passkey and no dialog** (iOS, macOS): The system asks for the passkey itself, createBond cannot be given one and throws androidOnly.
6. **Create a bond with a given passkey and no dialog** (Linux): A passkey needs a BlueZ pairing agent, which the plugin does not implement, createBond throws androidOnly.
7. **Create a bond with a given passkey and no dialog** (Web): The browser has no pairing API, createBond throws androidOnly.
8. **Remove the bond with a device** (Android): Uses the hidden BluetoothDevice.removeBond() through reflection, which a vendor or a later Android version may block.
9. **Remove the bond with a device** (iOS, macOS): CoreBluetooth cannot remove bonds, removeBond throws androidOnly.
10. **Remove the bond with a device** (Linux): The plugin has no removeBond and the library throws androidOnly before it calls the plugin.
11. **Remove the bond with a device** (Web): The browser has no pairing API, removeBond throws androidOnly.
12. **Read and follow the bond state of a device** (iOS, macOS): CoreBluetooth reports no bond state, bondState throws androidOnly.
13. **Read and follow the bond state of a device** (Linux): The plugin reports the bond state of BlueZ, but the library throws androidOnly before it calls the plugin.
14. **Read and follow the bond state of a device** (Web): The browser has no pairing API, bondState throws androidOnly.
15. **List the bonded devices** (iOS, macOS): CoreBluetooth has no list of bonded devices, an empty list is returned.
16. **List the bonded devices** (Web): The browser has no list of bonded devices, an empty list is returned.

## L2CAP

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Open an L2CAP channel to a device and exchange data | `BluetoothDevice.openL2CapChannel`, `BluetoothL2capChannel.write`, `BluetoothL2capChannel.read`, `BluetoothL2capChannel.close` | ⚠️ [1] | ✅ | ✅ | 🚧 [2] | ❌ [3] |
| Listen for L2CAP channels that devices open | `FlutterBlueMax.listenL2capChannel`, `FlutterBlueMax.stopL2capServer`, `FlutterBlueMax.onL2capConnected` | ⚠️ [4] | ⚠️ [5] | ⚠️ [5] | 🚧 [6] | ❌ [7] |
| Follow the data and the closing of L2CAP channels | `FlutterBlueMax.onL2capReceived`, `FlutterBlueMax.onL2capClosed`, `BluetoothL2capChannel.onL2CapChannelReceived`, `BluetoothL2capChannel.onClosed` | ✅ | ✅ | ✅ | 🚧 [8] | ❌ [9] |
| Choose whether an L2CAP channel is encrypted | `BluetoothDevice.openL2CapChannel(secure)`, `FlutterBlueMax.listenL2capChannel(secure)` | ✅ | ⚠️ [10] | ⚠️ [10] | 🚧 [11] | ❌ [12] |

1. **Open an L2CAP channel to a device and exchange data** (Android): Needs Android 10 (API 29).
2. **Open an L2CAP channel to a device and exchange data** (Linux): The plugin has no L2CAP, openL2CapChannel throws UnimplementedError.
3. **Open an L2CAP channel to a device and exchange data** (Web): Web Bluetooth has no L2CAP, openL2CapChannel throws applePlatformOnly.
4. **Listen for L2CAP channels that devices open** (Android): Needs Android 10 (API 29).
5. **Listen for L2CAP channels that devices open** (iOS, macOS): CoreBluetooth does not tell which central connected, channels of a server carry the placeholder id server.
6. **Listen for L2CAP channels that devices open** (Linux): The plugin has no L2CAP, listenL2capChannel throws UnimplementedError.
7. **Listen for L2CAP channels that devices open** (Web): Web Bluetooth has no L2CAP, listenL2capChannel throws applePlatformOnly.
8. **Follow the data and the closing of L2CAP channels** (Linux): The plugin has no L2CAP, the streams never emit.
9. **Follow the data and the closing of L2CAP channels** (Web): Web Bluetooth has no L2CAP, the streams never emit.
10. **Choose whether an L2CAP channel is encrypted** (iOS, macOS): The flag only applies to a listening server, the security of an opened channel is chosen by the peer.
11. **Choose whether an L2CAP channel is encrypted** (Linux): The plugin has no L2CAP, the calls throw UnimplementedError.
12. **Choose whether an L2CAP channel is encrypted** (Web): Web Bluetooth has no L2CAP, the calls throw applePlatformOnly.

## Events

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Follow the connection state of all devices | `FlutterBlueMax.events.onConnectionStateChanged` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Follow the MTU of all devices | `FlutterBlueMax.events.onMtuChanged` | ✅ | ✅ | ✅ | 🚧 [1] | ❌ [2] |
| Follow the RSSI reads of all devices | `FlutterBlueMax.events.onReadRssi` | ✅ | ✅ | ✅ | ✅ | ❌ [3] |
| Follow the service changes of all devices | `FlutterBlueMax.events.onServicesReset` | ✅ | ✅ | ✅ | ⚠️ [4] | ❌ [5] |
| Follow the service discovery of all devices | `FlutterBlueMax.events.onDiscoveredServices` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Follow the characteristic values that all devices send or return | `FlutterBlueMax.events.onCharacteristicReceived` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Follow the characteristic writes to all devices | `FlutterBlueMax.events.onCharacteristicWritten` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Follow the descriptor reads of all devices | `FlutterBlueMax.events.onDescriptorRead` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Follow the descriptor writes to all devices | `FlutterBlueMax.events.onDescriptorWritten` | ✅ | ✅ | ✅ | ⚠️ [6] | ⚠️ [6] |
| Follow the name changes of all devices | `FlutterBlueMax.events.onNameChanged` | 🚧 [7] | ✅ | ✅ | ✅ | ❌ [8] |
| Follow the bond state of all devices | `FlutterBlueMax.events.onBondStateChanged` | ✅ | ❌ [9] | ❌ [9] | ✅ | ❌ [10] |

1. **Follow the MTU of all devices** (Linux): The plugin reports no MTU, the stream never emits.
2. **Follow the MTU of all devices** (Web): The browser reports no MTU, the stream never emits.
3. **Follow the RSSI reads of all devices** (Web): The browser cannot read the RSSI, the stream never emits.
4. **Follow the service changes of all devices** (Linux): Approximated by a change of the UUIDs property that BlueZ keeps for the device.
5. **Follow the service changes of all devices** (Web): The browser reports no service changes, the stream never emits.
6. **Follow the descriptor writes to all devices** (Linux, Web): The CCCD write of setNotifyValue is not reported.
7. **Follow the name changes of all devices** (Android): The Dart side listens, but the Android plugin never sends the event.
8. **Follow the name changes of all devices** (Web): The browser reports no name changes, the stream never emits.
9. **Follow the bond state of all devices** (iOS, macOS): CoreBluetooth reports no bonds, the stream never emits.
10. **Follow the bond state of all devices** (Web): The browser reports no bonds, the stream never emits.

## Errors and diagnostics

| Feature | API | Android | iOS | macOS | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Choose how much the library and its plugin log, and read the log | `FlutterBlueMax.setLogLevel`, `FlutterBlueMax.logLevel`, `FlutterBlueMax.logs` | ✅ | ✅ | ✅ | ✅ | ⚠️ [1] |
| Report an ATT error of the peer with its code | `FlutterBlueMaxException.code`, `FlutterBlueMaxException.description`, `FbpError` | ✅ | ✅ | ✅ | ⚠️ [2] | ⚠️ [3] |
| Fail an operation on a disconnected device with deviceIsDisconnected | `FbpErrorCode.deviceIsDisconnected` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fail an operation that is not answered in time with timeout | `FbpErrorCode.timeout` | ✅ | ✅ | ✅ | ✅ | 🚧 [4] |
| Fail cleanly when a characteristic lacks the property an operation needs | `BluetoothCharacteristic.read`, `BluetoothCharacteristic.write`, `BluetoothCharacteristic.setNotifyValue` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fail a running operation with adapterIsOff when the adapter is switched off | `FbpErrorCode.adapterIsOff` | ✅ | ✅ | ✅ | ✅ | ❌ [5] |

1. **Choose how much the library and its plugin log, and read the log** (Web): Only the Dart side of the library logs, the web plugin has no log of its own.
2. **Report an ATT error of the peer with its code** (Linux): The error text of BlueZ is the description and the code is always 0.
3. **Report an ATT error of the peer with its code** (Web): The error text of the browser is the description and the code is always 0.
4. **Fail an operation that is not answered in time with timeout** (Web): The platform call awaits the whole operation, so an operation that is not answered never fails with timeout.
5. **Fail a running operation with adapterIsOff when the adapter is switched off** (Web): The adapter state never changes in the browser, no operation fails with adapterIsOff.
