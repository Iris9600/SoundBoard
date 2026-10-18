import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/name_identity.dart';
import '../services/name_registry.dart';
import 'main_page.dart';
import 'web_app_page.dart';

class NameGate extends StatefulWidget {
  final NameRegistry? registry;
  const NameGate({super.key, this.registry});
  @override
  State<NameGate> createState() => _NameGateState();
}

class _NameGateState extends State<NameGate> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _activeName;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _remember = false;
  bool _isLogin = true;
  late final _registry = widget.registry ?? NameRegistry();

  String _databaseError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Database access is blocked. The app administrator needs to update Firestore security rules.';
    }
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'Unable to reach the database. Check your connection and try again.';
    }
    return 'Unable to ${_isLogin ? 'log in' : 'register'}. Please try again. (${error.code})';
  }

  void _selectMode(Set<bool> selection) {
    _form.currentState?.reset();
    _name.clear();
    setState(() {
      // Selecting the current mode clears the form while keeping it selected.
      if (selection.isNotEmpty) _isLogin = selection.single;
      _remember = false;
      _error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final name = await NameIdentity.load();
      if (name != null) await _registry.login(name);
      if (!mounted) return;
      setState(() {
        _activeName = name;
        _loading = false;
      });
    } on NameRegistryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _databaseError(error);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Unable to check your saved name. Check your connection and try logging in.';
        _loading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = NameIdentity.normalize(_name.text);
    var errorMessage =
        'Unable to ${_isLogin ? 'log in' : 'register'}. Please try again.';
    try {
      if (_isLogin) {
        await _registry.login(name);
      } else {
        await _registry.register(name);
      }
      errorMessage =
          'Unable to save your preference. Please retry${_isLogin ? '.' : ' using Login; your name has been registered.'}';
      await NameIdentity.remember(_isLogin && _remember ? name : null);
      if (!mounted) return;
      setState(() => _activeName = name);
    } on NameRegistryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _error = _databaseError(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchName() async {
    try {
      await NameIdentity.remember(null);
      if (!mounted) return;
      setState(() {
        _name.text = _activeName ?? '';
        _activeName = null;
        _remember = false;
        _isLogin = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to forget your name. Please retry.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = _activeName;
    if (name != null) {
      final id = NameIdentity.idFor(name);
      return kIsWeb
          ? WebAppPage(
              key: ValueKey(id),
              userName: name,
              onSwitchName: _switchName,
            )
          : MainPage(
              key: ValueKey(id),
              userName: name,
              onSwitchName: _switchName,
            );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SoundBoard')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Login')),
                      ButtonSegment(value: false, label: Text('Register')),
                    ],
                    selected: {_isLogin},
                    onSelectionChanged: _busy ? null : _selectMode,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter your name',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use the same name to open your sound library on any device. No password required. Anyone using this name can access its sounds.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _continue(),
                    validator: (value) {
                      final name = NameIdentity.normalize(value ?? '');
                      if (name.isEmpty) return 'Please enter your name';
                      if (name.length > 80) return 'Use 80 characters or fewer';
                      return null;
                    },
                  ),
                  if (_isLogin)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remember me'),
                      value: _remember,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _remember = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _continue,
                    child: Text(
                      _busy ? 'Opening...' : (_isLogin ? 'Login' : 'Register'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
