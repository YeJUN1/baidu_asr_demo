import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart'; // ✅ 新增导入
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart'; // ✅ 加入 import
import 'baidu_asr_service.dart';
import 'deepseek_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Wakeup Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const VoiceWakeupHomePage(),
    );
  }
}

class VoiceWakeupHomePage extends StatefulWidget {
  const VoiceWakeupHomePage({super.key});

  @override
  State<VoiceWakeupHomePage> createState() => _VoiceWakeupHomePageState();
}

class _VoiceWakeupHomePageState extends State<VoiceWakeupHomePage> {
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  bool _isRecording = false;
  String _transcription = "";
  String _deepSeekReply = "";
  String? _lastRecordedFilePath; // ✅ 存储最近录音路径

  final String _accessKey =
      '9oTAE9qM71R2a9lMWKOhtWG82MYIxA8qzuBN2jMKoWnbiCKPMcNdSw==';

  final Record _recorder = Record();
  final FlutterTts _tts = FlutterTts();

  late String _appDocDirPath;

  @override
  void initState() {
    super.initState();
    _initAppDirectory();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voice_wakeup_service',
        channelName: 'Voice Wakeup Background Service',
        channelDescription: 'Keep listening for wake words in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: const [NotificationButton(id: 'stop', text: 'Stop')],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _startForegroundTask();
    _initPorcupine();
  }

  Future<void> _initAppDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDocDirPath = dir.path;
    print("应用私有目录路径: $_appDocDirPath");
  }

  Future<void> _startForegroundTask() async {
    if (await Permission.microphone.request().isGranted) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Listening for wake word',
        notificationText: 'App is running in the background',
      );
    }
  }

  Future<void> _initPorcupine() async {
    try {
      final keywordAsset = 'assets/hey-mango_en_android_v3_0_0.ppn';
      final modelPath = 'assets/porcupine_params.pv';

      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [keywordAsset],
        _onWakeWordDetected,
        modelPath: modelPath,
        sensitivities: [0.65],
      );

      await _porcupineManager?.start();

      setState(() {
        _isListening = true;
      });
    } catch (e) {
      print('Error initializing Porcupine: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<String?> _recordAudio() async {
    try {
      if (await _recorder.hasPermission()) {
        final originalPath = '$_appDocDirPath/audio_raw.wav';
        final convertedPath = '$_appDocDirPath/audio.wav';

        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }

        await _recorder.start(
          path: originalPath,
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          samplingRate: 16000,
        );

        setState(() {
          _isRecording = true;
        });

        await Future.delayed(const Duration(seconds: 5));
        await _recorder.stop();

        // ✅ 转码为单声道
        final ffmpegCmd = "-y -i $originalPath -ac 1 -ar 16000 -sample_fmt s16 $convertedPath";
        await FFmpegKit.execute(ffmpegCmd);

        // 检查转码结果
        if (!File(convertedPath).existsSync()) {
          print("音频转码失败");
          return null;
        }

        setState(() {
          _isRecording = false;
          _lastRecordedFilePath = convertedPath;
        });

        return convertedPath;
      } else {
        print("录音权限被拒绝");
        return null;
      }
    } catch (e) {
      print("录音异常: $e");
      return null;
    }
  }

  void _onWakeWordDetected(int index) async {
    print("唤醒词检测到！准备暂停监听并开始录音...");
    await _porcupineManager?.stop();

    final audioFilePath = await _recordAudio();
    if (audioFilePath == null) {
      print("录音失败或权限不足，重新启动监听");
      await _porcupineManager?.start();
      return;
    }

    print("录音完成，路径：$audioFilePath，开始识别...");

    final resultText = await BaiduAsrService.transcribeAudio(audioFilePath);
    print("识别结果: $resultText");

    setState(() {
      _transcription = resultText;
    });

    String reply;

    try {
      if (resultText.trim().isEmpty) {
        reply = "我没有听清楚，请再说一遍。";
      } else if (resultText.contains("语音识别失败")) {
        reply = "语音识别出错了。";
      } else {
        print("调用 DeepSeek 生成回复...");
        reply = await DeepSeekService.chat(resultText);
        print("DeepSeek 回复: $reply");
      }
    } catch (e, st) {
      print("调用 AI 接口异常: $e\n$st");
      reply = "抱歉，AI接口调用失败。";
    }

    setState(() {
      _deepSeekReply = reply;
    });

    print("开始朗读回复...");
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.45);
    await _tts.speak(reply).catchError((e) => print("朗读异常: $e"));

    print("回复朗读结束，重新启动监听...");
    await _porcupineManager?.start();
  }

  Future<void> _exportRecording() async {
    if (_lastRecordedFilePath == null || !File(_lastRecordedFilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的录音')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(_lastRecordedFilePath!)],
      text: '导出我的录音文件',
    );
  }

  @override
  void dispose() {
    _porcupineManager?.stop();
    _porcupineManager?.delete();
    FlutterForegroundTask.stopService();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text("Voice Wakeup + Baidu ASR + DeepSeek")),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isListening ? '正在监听唤醒词...' : '未启动监听',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRecording ? '录音中，请说话...' : '未录音',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isListening
                      ? () async {
                    await _porcupineManager?.stop();
                    setState(() => _isListening = false);
                  }
                      : () async {
                    await _porcupineManager?.start();
                    setState(() => _isListening = true);
                  },
                  child: Text(_isListening ? '停止监听' : '开始监听'),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _lastRecordedFilePath != null ? _exportRecording : null,
                  child: const Text("导出最近录音"),
                ),
                const SizedBox(height: 30),
                Text("转写结果：",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _transcription.isEmpty ? "暂无识别结果" : _transcription,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text("DeepSeek 回复：",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _deepSeekReply.isEmpty ? "暂无回复" : _deepSeekReply,
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
