import 'package:flutter/material.dart';
import '../services/device_identity.dart';
import '../services/device_name.dart';
import 'main_page.dart';

class DeviceGate extends StatefulWidget {
  const DeviceGate({super.key});

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> {
  late Future<({String id, String name})> _device;

  Future<({String id, String name})> _loadDevice() async {
    final id = await DeviceIdentity.loadOrCreate();
    final name = await DeviceName.load();
    return (id: id, name: name);
  }

  @override
  void initState() {
    super.initState();
    _device = _loadDevice();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String id, String name})>(
      future: _device,
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
                      _device = _loadDevice();
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
        return MainPage(
          deviceId: snapshot.data!.id,
          deviceName: snapshot.data!.name,
        );
      },
    );
  }
}
