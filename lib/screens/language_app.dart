import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';

import '../components/language_data.dart';

class LanguageApp extends StatefulWidget {
  const LanguageApp({super.key});

  @override
  State<LanguageApp> createState() => _LanguageAppState();
}

class _LanguageAppState extends State<LanguageApp> {
  int firstSelectedIndex = 0;
  int secondSelectedIndex = 1;
  final translator = GoogleTranslator();
  final LanguageData languageData = LanguageData();
  final FocusNode _textFieldFocusNode = FocusNode();
  final FlutterTts flutterTts = FlutterTts();
  late TextEditingController _textEditingController;
  Timer? _typingTimer;
  String text = '';
  int textLength = 0;
  String translatedText = '';
  int translatedTextLength = 0;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _wordsSpoken = '';
  String detectedLanguageText = '';
  bool isMan = false;

  @override
  void initState() {
    super.initState();
    initSpeech();
    // Update the length of translated text
    translatedTextLength = translatedText.length;
    firstSelectedIndex = 0;
    secondSelectedIndex = 1;
    _textEditingController = TextEditingController(text: text);
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: onSpeechResult);
    setState(() {
      _speechEnabled = _speechToText.isListening;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _speechEnabled = false;
    });
  }

  void handleLanguageSelection(String selectedLanguage, String text) {
    if (languageData.languageLocales.containsKey(selectedLanguage)) {
      _speak(text, languageData.languageLocales[selectedLanguage]!);
    } else {
      // Fallback to English if the language is not found
      _speak(text, 'en-US');
    }
  }

  void onSpeechResult(result) {
    setState(() {
      _wordsSpoken = "${result.recognizedWords}";
      _textEditingController.text = _wordsSpoken;
      text = _textEditingController.text;
      // Pass the recognized words directly
      getTranslatedText(
          _wordsSpoken,
          languageData.languages[firstSelectedIndex],
          languageData.languages[secondSelectedIndex]);
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, String language) async {
    await flutterTts.setLanguage(language);
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  Future<void> getSupportedLanguages() async {
    List<dynamic> languages = await flutterTts.getLanguages;
    print("Supported Languages: $languages");
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: translatedText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Text copied to clipboard!',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void getTranslatedText(
      String text, String firstLanguage, String secondLanguage) async {
    try {
      final translation = await translator.translate(text,
          from: firstLanguage, to: secondLanguage);
      setState(() {
        translatedText = translation.toString();
        translatedTextLength = translatedText.length;
      });
    } catch (e) {
      print('Translation error: $e');
    }
  }

  void getVoices() async {
    List<dynamic> voices = await flutterTts.getVoices;
    print(voices);
  }

  void detectLanguageText(String text) async {
    // Detecting the language of the text
    var detectedLanguage = await translator.translate(text);
    setState(() {
      detectedLanguage.sourceLanguage.toString() == 'Automatic'
          ? detectedLanguageText = 'English'
          : detectedLanguageText = detectedLanguage.sourceLanguage.toString();
    });

    String? key = languageData.languageCodesData.entries
        .firstWhere((entry) => entry.value == detectedLanguageText,
            orElse: () => const MapEntry('', ''))
        .key;

    if (key.isNotEmpty) {
      final entriesList = languageData.languageCodesData.entries.toList();

      // Example: Get the index of the 'fr' key
      final index = entriesList.indexWhere((entry) => entry.key == key);
      setState(() {
        firstSelectedIndex = index;
      });
    } else {
      print('Value not found in the map.');
    }
    getTranslatedText(
        _textEditingController.text,
        languageData.languages[firstSelectedIndex],
        languageData.languages[secondSelectedIndex]);
  }

  void swapLanguages() {
    int middle = firstSelectedIndex;
    String middleText = text;
    setState(() {
      firstSelectedIndex = secondSelectedIndex;
      secondSelectedIndex = middle;
      text = translatedText;
      translatedText = middleText;
      _textEditingController.text = text;
    });

    // Unfocus the TextField and set the text to the translated text
    _textFieldFocusNode.unfocus();

    detectLanguageText(_textEditingController.text);
  }

  void _showLanguageSelectionModal(BuildContext context, bool isFirst) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black, // Background color of the modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          child: ListView.builder(
            itemCount: languageData.languageFullNames.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 10.0,
                  backgroundImage: NetworkImage(
                    languageData.languageFlags[index],
                  ),
                ),
                title: Text(
                  languageData.languageFullNames[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () {
                  setState(() {
                    if (isFirst) {
                      firstSelectedIndex = index;
                    } else {
                      secondSelectedIndex = index;
                      getTranslatedText(
                          _textEditingController.text,
                          languageData.languages[firstSelectedIndex],
                          languageData.languages[secondSelectedIndex]);
                    }
                    _textFieldFocusNode.unfocus();
                  });
                  Navigator.pop(context); // Close the modal
                },
              );
            },
          ),
        );
      },
    );
  }

  void _onTextChanged(String value) {
    setState(() {
      text = value;
      textLength = text.length;
    });

    // Reset the timer if the user is still typing
    if (_typingTimer != null) {
      _typingTimer!.cancel();
    }

    // Start a new timer when the user stops typing for a specified duration
    _typingTimer = Timer(const Duration(seconds: 1), () {
      if (value.isEmpty) {
        setState(() {
          translatedText = '';
          translatedTextLength = 0;
        });
      } else {
        detectLanguageText(value);
        getTranslatedText(value, languageData.languages[firstSelectedIndex],
            languageData.languages[secondSelectedIndex]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF212529),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // const CircleAvatar(
                  //   radius: 20.0,
                  //   backgroundColor: Color(0xffF5F5DC),
                  //   child: Icon(Icons.arrow_back),
                  // ),
                  Text(
                    'Translate',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 25.0),
                  ),
                  // GestureDetector(
                  //   onTap: () {
                  //     showModalBottomSheet(
                  //         context: context,
                  //         backgroundColor:
                  //             Colors.black, // Background color of the modal
                  //         shape: const RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.vertical(
                  //               top: Radius.circular(15.0)),
                  //         ),
                  //         builder: (BuildContext context) {
                  //           return Padding(
                  //             padding: const EdgeInsets.symmetric(
                  //                 horizontal: 20.0, vertical: 40),
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.stretch,
                  //               children: [
                  //                 const Padding(
                  //                   padding: EdgeInsets.only(bottom: 30.0),
                  //                   child: Text(
                  //                     'SELECT GENDER FOR VOICE',
                  //                     style: TextStyle(
                  //                         color: Colors.white,
                  //                         fontWeight: FontWeight.w900,
                  //                         fontSize: 20.0),
                  //                   ),
                  //                 ),
                  //                 ListTile(
                  //                   leading: const CircleAvatar(
                  //                     backgroundColor: Colors.white,
                  //                     radius: 20.0,
                  //                     child: Icon(Icons.male),
                  //                   ),
                  //                   title: const Text(
                  //                     'MALE VOICE',
                  //                     style: TextStyle(
                  //                       color: Colors.white,
                  //                       fontWeight: FontWeight.w900,
                  //                     ),
                  //                   ),
                  //                   onTap: () {
                  //                     setState(() {
                  //                       isMan = true;
                  //                     });
                  //                     Navigator.pop(context); // Close the modal
                  //                   },
                  //                 ),
                  //                 const SizedBox(
                  //                   height: 20.0,
                  //                 ),
                  //                 ListTile(
                  //                   leading: const CircleAvatar(
                  //                     backgroundColor: Colors.white,
                  //                     radius: 20.0,
                  //                     child: Icon(Icons.female),
                  //                   ),
                  //                   title: const Text(
                  //                     'FEMALE VOICE',
                  //                     style: TextStyle(
                  //                       color: Colors.white,
                  //                       fontWeight: FontWeight.w900,
                  //                     ),
                  //                   ),
                  //                   onTap: () {
                  //                     setState(() {
                  //                       isMan = false;
                  //                     });
                  //                     Navigator.pop(context); // Close the modal
                  //                   },
                  //                 ),
                  //               ],
                  //             ),
                  //           );
                  //         });
                  //   },
                  //   child: Container(
                  //     padding: const EdgeInsets.all(2.0), // Border width
                  //     decoration: const BoxDecoration(
                  //       color: Colors.white, // Border color
                  //       shape: BoxShape.circle,
                  //     ),
                  //     child: CircleAvatar(
                  //       radius: 20.0,
                  //       backgroundColor: const Color(0XFF212529),
                  //       child: Icon(
                  //         isMan ? Icons.male : Icons.female,
                  //         size: 25.0,
                  //         color: Colors.white,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: const Color(0xffF5F5DC), // Border color
                          width: 2.0, // Border width
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10.0)),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _showLanguageSelectionModal(context, true);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleAvatar(
                              radius: 10.0,
                              backgroundImage: NetworkImage(
                                languageData.languageFlags[firstSelectedIndex],
                              ),
                            ),
                            const SizedBox(
                              width: 25,
                            ),
                            Text(
                              languageData.languageCode[firstSelectedIndex],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20.0,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        swapLanguages();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12.0), // Border width
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: const Color(0xffF5F5DC), // Border color
                            width: 2.0, // Border width
                          ),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          size: 30.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: const Color(0xffF5F5DC), // Border color
                          width: 2.0, // Border width
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10.0)),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _showLanguageSelectionModal(context, false);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleAvatar(
                              radius: 10.0,
                              backgroundImage: NetworkImage(
                                languageData.languageFlags[secondSelectedIndex],
                              ),
                            ),
                            const SizedBox(
                              width: 25,
                            ),
                            Text(
                              languageData.languageCode[secondSelectedIndex],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20.0,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _speechToText.isListening
                          ? const Center(
                              child: Text(
                                'Listening...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.0,
                                ),
                              ),
                            )
                          : Container(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0, top: 20.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            // // Semi-transparent background color
                            border: Border.all(
                              color: const Color(0xffF5F5DC), // Border color
                              width: 2.0, // Border width
                            ),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10.0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 10.0, sigmaY: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Text(
                                          'Detected Language: $detectedLanguageText',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: TextField(
                                          focusNode: _textFieldFocusNode,
                                          // Assign the FocusNode here
                                          controller: _textEditingController,
                                          onChanged: _onTextChanged,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            hintStyle:
                                                TextStyle(color: Colors.grey),
                                            hintText:
                                                'Enter text...', // Optional: Add a hint text
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 25.0, // Set the text size
                                          ),
                                          cursorColor: Colors.white,
                                          maxLines:
                                              null, // Allow multiple lines
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0, top: 15.0),
                                        child: SizedBox(
                                          height: 2.0,
                                          child: Container(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            textLength <= 1
                                                ? '${textLength.toString()} character'
                                                : '${textLength.toString()} characters',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18.0),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                child: const Icon(
                                                  Icons.volume_up,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                                onTap: () {
                                                  String selectedLanguage =
                                                      languageData.languages[
                                                          firstSelectedIndex];
                                                  handleLanguageSelection(
                                                      selectedLanguage, _textEditingController.text);
                                                },
                                              ),
                                              const SizedBox(
                                                width: 10.0,
                                              ),
                                              GestureDetector(
                                                child: Icon(
                                                  _speechToText.isNotListening
                                                      ? Icons.mic_off
                                                      : Icons.keyboard_voice,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                                onTap: () {
                                                  setState(() {
                                                    print(
                                                        'Toggled listening state'); // Debug: Check if this is being printed
                                                    if (_speechToText
                                                        .isListening) {
                                                      print(
                                                          'Stopping listening'); // Debug: Check if this is being printed
                                                      _stopListening(); // Stop listening
                                                    } else {
                                                      print(
                                                          'Starting listening'); // Debug: Check if this is being printed
                                                      _startListening(); // Start listening
                                                    }
                                                  });
                                                },
                                              )
                                            ],
                                          )
                                        ],
                                      )
                                    ],
                                  )),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          // // Semi-transparent background color
                          border: Border.all(
                            color: const Color(0xffF5F5DC), // Border color
                            width: 2.0, // Border width
                          ),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 18.0),
                                    child: SelectableText(
                                      translatedText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 25.0, // Set the text size
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 15.0, bottom: 8.0),
                                    child: SizedBox(
                                      height: 2.0,
                                      child: Container(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        translatedTextLength <= 1
                                            ? '${translatedTextLength.toString()} character'
                                            : '${translatedTextLength.toString()} characters',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18.0),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            child: const Icon(
                                              Icons.volume_up,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onTap: () {
                                              String selectedLanguage =
                                                  languageData.languages[
                                                      secondSelectedIndex];
                                              handleLanguageSelection(
                                                  selectedLanguage,
                                                  translatedText);
                                            },
                                          ),
                                          const SizedBox(
                                            width: 13.0,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 5.0),
                                            child: GestureDetector(
                                              onTap: _copyToClipboard,
                                              child: const Icon(
                                                Icons.copy_outlined,
                                                color: Colors.white,
                                                size: 25.0,
                                              ),
                                            ),
                                          )
                                        ],
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
