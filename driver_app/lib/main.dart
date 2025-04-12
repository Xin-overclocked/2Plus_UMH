import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grab Driver Voice Assistant',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _hasIncomingOrder = false;
  bool _orderAccepted = false;
  bool _isAssistantAwake = false;
  String _lastWords = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Settings
  String _wakeWord = 'hey grab';
  String _emergencyCode = '暗号';
  Map<String, String> _customCommands = {
    'navigate home': 'Starting navigation to home',
    'call passenger': 'Calling passenger',
    'show earnings': 'Showing today\'s earnings',
  };

  // Sample order data
  final List<Map<String, String>> _sampleOrders = [
    {
      'pickup': 'KLIA Terminal 1',
      'dropoff': 'KL Sentral Station',
      'distance': '55.0 km',
      'duration': '45 mins',
    },
    {
      'pickup': 'Mid Valley Megamall',
      'dropoff': 'Petronas Twin Towers',
      'distance': '7.5 km',
      'duration': '20 mins',
    },
    {
      'pickup': 'Bukit Bintang',
      'dropoff': 'Sunway Pyramid',
      'distance': '15.0 km',
      'duration': '30 mins',
    },
  ];

  Map<String, String> _currentOrder = {};

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
    _loadSettings();

    _currentOrder = _sampleOrders[0];

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 15).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: buildAppBar(),
      body: Stack(
        children: [
          // Map Background (placeholder)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mapview.png'),
                // Replace with your image path
                fit:
                    BoxFit
                        .cover, // Adjusts the image to cover the entire container
              ),
            ),
            // color: Colors.grey[300],
            child: Center(
              // child: Text(
              //   'Map View',
              //   style: TextStyle(color: Colors.grey[700], fontSize: 20),
              // ),
            ),
          ),

          // Assistant status indicator
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              // child: commandBar(isAssistantAwake: _isAssistantAwake, wakeWord: _wakeWord),
            ),
          ),

          // Order Card when there's an incoming order
          if (_hasIncomingOrder) acceptOrderBar(),
          // Simulation Controls (dropdown menu)
          if (!_hasIncomingOrder) dropdownSimulationCtrl(),
          if (!_hasIncomingOrder) settingsButton(),

          // Microphone Button
          microphoneButton(),
        ],
      ),
    );
  }

  Positioned settingsButton() {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: IconButton(
          icon: const Icon(Icons.settings),
          color: Colors.white,
          onPressed: _openSettings,
        ),
        // ),
      ),
    );
  }

  Positioned dropdownSimulationCtrl() {
    return Positioned(
      top: 50,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: PopupMenuButton<int>(
          onSelected: (int result) {
            _simulateIncomingOrder(result);
          },
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu, color: Colors.white),
              const SizedBox(width: 4),
            ],
          ),
          color: Colors.grey[850],
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<int>>[
                const PopupMenuItem<int>(
                  value: 0,
                  child: Text(
                    'KLIA → KL Sentral',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem<int>(
                  value: 1,
                  child: Text(
                    'Mid Valley → Twin Tower',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem<int>(
                  value: 2,
                  child: Text(
                    'Bukit Bintang → Sunway Pyramid',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
        ),
      ),
    );
  }

  Positioned microphoneButton() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 80 + (_isListening ? _animation.value * 2 : 0),
              height: 80 + (_isListening ? _animation.value * 2 : 0),
              decoration: BoxDecoration(
                color:
                    _isListening
                        ? (_isAssistantAwake ? Colors.green : Colors.amber)
                            .withOpacity(0.3)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                          _isListening
                              ? Colors.green
                              : (_isAssistantAwake
                                  ? Colors.green[700]
                                  : Colors.red),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Positioned acceptOrderBar() {
    return Positioned(
      top: 90,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[700],
                    radius: 20,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 23),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PICKUP',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentOrder['pickup']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'DROP-OFF',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentOrder['dropoff']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_currentOrder['distance']} • ${_currentOrder['duration']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 13),
                    ],
                  ),
                ],
              ),


              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _declineOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _orderAccepted ? Colors.grey : Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _acceptOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _orderAccepted ? Colors.green[700] : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: const Text('Grab Driver Assistant'),
      backgroundColor: Colors.green,
      actions: [
        // settingButton(),
        dropdownSimulationCtrl(),
      ],
    );
  }

  // IconButton settingButton() => IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings);

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wakeWord = prefs.getString('wakeWord') ?? 'hey grab';
      _emergencyCode = prefs.getString('emergencyCode') ?? '暗号';

      // Load custom commands
      final customCommandsKeys =
          prefs.getStringList('customCommandsKeys') ?? [];
      final customCommandsValues =
          prefs.getStringList('customCommandsValues') ?? [];

      _customCommands = {};
      for (int i = 0; i < customCommandsKeys.length; i++) {
        if (i < customCommandsValues.length) {
          _customCommands[customCommandsKeys[i]] = customCommandsValues[i];
        }
      }
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wakeWord', _wakeWord);
    await prefs.setString('emergencyCode', _emergencyCode);

    // Save custom commands
    await prefs.setStringList(
      'customCommandsKeys',
      _customCommands.keys.toList(),
    );
    await prefs.setStringList(
      'customCommandsValues',
      _customCommands.values.toList(),
    );
  }

  void _initializeSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _simulateIncomingOrder(int orderIndex) {
    setState(() {
      _currentOrder = _sampleOrders[orderIndex];
      _hasIncomingOrder = true;
      _orderAccepted = false;
    });

    _speak('New order received!');
    _startListening();
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _lastWords = '';
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords.toLowerCase();
              print('Heard: $_lastWords');

              // Check for wake word
              if (!_isAssistantAwake &&
                  _lastWords.contains(_wakeWord.toLowerCase())) {
                _activateAssistant();
                return;
              }

              // Check for emergency code
              if (_lastWords.contains(_emergencyCode.toLowerCase())) {
                _handleEmergency();
                return;
              }

              // Process commands only if assistant is awake
              // if (_isAssistantAwake) {
              if (_hasIncomingOrder) {
                if (_lastWords.contains('accept')) {
                  _acceptOrder();
                } else if (_lastWords.contains('decline') ||
                    _lastWords.contains('reject')) {
                  _declineOrder();
                }
              }

              // Check custom commands
              // _checkCustomCommands();
              // }
            });
          },
        );
      }
    }
  }

  void _activateAssistant() {
    setState(() {
      _isAssistantAwake = true;
    });
    _speak('Grab assistant activated. How can I help you?');

    // Auto sleep after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (_isAssistantAwake) {
        setState(() {
          _isAssistantAwake = false;
        });
        _speak('Grab assistant going to sleep');
      }
    });
  }

  void _handleEmergency() {
    // Stop current operations
    _stopListening();
    setState(() {
      _hasIncomingOrder = false;
      _orderAccepted = false;
    });
    _speak('Emergency protocol activated. Contacting emergency services.');

    // Show emergency dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'EMERGENCY MODE ACTIVATED',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'Contacting emergency services and sending your current location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel Emergency'),
            ),
          ],
        );
      },
    );
  }

  void _checkCustomCommands() {
    _customCommands.forEach((command, response) {
      if (_lastWords.contains(command.toLowerCase())) {
        _speak(response);
      }
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _acceptOrder() {
    _stopListening();
    setState(() {
      _orderAccepted = true;
      _hasIncomingOrder = false;
    });
    _speak('Order accepted. Navigation starting.');
  }

  void _declineOrder() {
    _stopListening();
    setState(() {
      _hasIncomingOrder = false;
      _orderAccepted = false;
    });
    _speak('Order declined.');
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SettingsScreen(
              wakeWord: _wakeWord,
              emergencyCode: _emergencyCode,
              customCommands: _customCommands,
              onSave: (wakeWord, emergencyCode, customCommands) {
                setState(() {
                  _wakeWord = wakeWord;
                  _emergencyCode = emergencyCode;
                  _customCommands = customCommands;
                });
                _saveSettings();
              },
            ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}

class commandBar extends StatelessWidget {
  const commandBar({
    super.key,
    required bool isAssistantAwake,
    required String wakeWord,
  }) : _isAssistantAwake = isAssistantAwake,
       _wakeWord = wakeWord;

  final bool _isAssistantAwake;
  final String _wakeWord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isAssistantAwake ? Colors.green : Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _isAssistantAwake ? 'Assistant Active' : 'Say "$_wakeWord" to activate',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String wakeWord;
  final String emergencyCode;
  final Map<String, String> customCommands;
  final Function(String, String, Map<String, String>) onSave;

  const SettingsScreen({
    Key? key,
    required this.wakeWord,
    required this.emergencyCode,
    required this.customCommands,
    required this.onSave,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _wakeWordController;
  late TextEditingController _emergencyCodeController;
  late Map<String, String> _customCommands;

  final _newCommandKeyController = TextEditingController();
  final _newCommandValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _wakeWordController = TextEditingController(text: widget.wakeWord);
    _emergencyCodeController = TextEditingController(
      text: widget.emergencyCode,
    );
    _customCommands = Map.from(widget.customCommands);
  }

  @override
  void dispose() {
    _wakeWordController.dispose();
    _emergencyCodeController.dispose();
    _newCommandKeyController.dispose();
    _newCommandValueController.dispose();
    super.dispose();
  }

  void _addCustomCommand() {
    final key = _newCommandKeyController.text;
    final value = _newCommandValueController.text;

    if (key.isNotEmpty && value.isNotEmpty) {
      setState(() {
        _customCommands[key] = value;
        _newCommandKeyController.clear();
        _newCommandValueController.clear();
      });
    }
  }

  void _removeCustomCommand(String key) {
    setState(() {
      _customCommands.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () {
              widget.onSave(
                _wakeWordController.text,
                _emergencyCodeController.text,
                _customCommands,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voice Assistant Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Wake word setting
              const Text(
                'Wake Word',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wakeWordController,
                decoration: const InputDecoration(
                  hintText: 'e.g., hey grab',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The phrase that activates the voice assistant',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // Emergency code setting
              const Text(
                'Emergency Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emergencyCodeController,
                decoration: const InputDecoration(
                  hintText: 'e.g., 暗号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Secret code word to activate emergency protocol',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // Custom commands
              const Text(
                'Custom Commands',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // List of existing custom commands
              ..._customCommands.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeCustomCommand(entry.key),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),

              // Add new command
              const Text(
                'Add New Command',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCommandKeyController,
                decoration: const InputDecoration(
                  hintText: 'Voice Command (e.g., navigate home)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCommandValueController,
                decoration: const InputDecoration(
                  hintText: 'Response (e.g., Starting navigation to home)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _addCustomCommand,
                icon: const Icon(Icons.add),
                label: const Text('Add Command'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
