import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepSeekService {
  static const String apiKey = 'sk-701d1e5f9f1944f8847e0798d00d8cab';
  static const String apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String model = 'deepseek-chat';

  static Future<String> chat(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": model,
          "messages": [
            {
              "role": "system",
              "content":
              "你是一个有帮助的AI语音助手。请用纯文本回答，禁止使用Markdown格式和代码。"
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7
        }),
      );

      print('DeepSeek API 状态码: ${response.statusCode}');

      // ✅ 使用 UTF-8 解码响应体，避免中文乱码
      final rawJson = utf8.decode(response.bodyBytes);
      print('DeepSeek API 响应体: $rawJson');

      if (response.statusCode == 200) {
        final data = jsonDecode(rawJson);

        if (data["choices"] != null &&
            data["choices"] is List &&
            data["choices"].isNotEmpty &&
            data["choices"][0]["message"] != null &&
            data["choices"][0]["message"]["content"] != null) {
          return data["choices"][0]["message"]["content"];
        } else {
          print("❌ DeepSeek 响应结构异常: $data");
          return "抱歉，AI暂时无法回答。";
        }
      } else {
        print("❌ DeepSeek 请求失败: $rawJson");
        return "抱歉，AI暂时无法回答。";
      }
    } catch (e) {
      print("❌ DeepSeek 请求异常: $e");
      return "抱歉，请求失败。";
    }
  }
}
