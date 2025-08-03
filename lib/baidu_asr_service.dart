import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class BaiduAsrService {
  static const String appId = '119676486';
  static const String apiKey = 'af8x6uMZ440JMn07Yu036qRf';
  static const String secretKey = '4ZoSkIG7imphAjXOpWC0NmRBOPBMfRn1';

  static String? _accessToken;

  static Future<String> _getAccessToken() async {
    if (_accessToken != null) return _accessToken!;

    final url =
        'https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=$apiKey&client_secret=$secretKey';

    final response = await http.post(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['access_token'] != null) {
      _accessToken = data['access_token'];
      return _accessToken!;
    } else {
      throw Exception('无法获取百度 Access Token: ${data['error_description']}');
    }
  }

  static Future<String> transcribeAudio(String filePath) async {
    final accessToken = await _getAccessToken();

    final audioBytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(audioBytes);

    final url = 'https://vop.baidu.com/server_api';

    final requestBody = json.encode({
      'format': 'wav',
      'rate': 16000,
      'channel': 1,
      'cuid': 'flutter_app_001',
      'token': accessToken,
      'len': audioBytes.length,
      'speech': audioBase64,
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    // 关键代码：防止中文乱码，先用 latin1 解码字节，再用 utf8 转码
    final bytes = response.bodyBytes;
    final latin1Decoded = latin1.decode(bytes);
    final utf8Decoded = utf8.decode(latin1Decoded.codeUnits);

    final responseJson = json.decode(utf8Decoded);

    if (responseJson['err_no'] == 0) {
      return responseJson['result'][0];
    } else {
      print('Baidu ASR Error: ${responseJson['err_msg']}');
      return '语音识别失败：${responseJson['err_msg']}';
    }
  }
}
