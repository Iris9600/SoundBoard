import 'package:flutter/material.dart';
import '../services/device_identity.dart';
import 'main_page.dart';

class DeviceGate extends StatefulWidget {
  const DeviceGate({super.key});

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> {
  late Future<String> _deviceId;

  @override
  void initState() {
    super.initState();
    _deviceId = DeviceIdentity.loadOrCreate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _deviceId,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to identify this device. Please retry.'),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _deviceId = DeviceIdentity.loadOrCreate();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return MainPage(deviceId: snapshot.data!);
      },
    );
  }
}
