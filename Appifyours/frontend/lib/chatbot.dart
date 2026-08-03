import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Import from main.dart instead of services
import 'main.dart';

// Gemini Service - Local implementation
class GeminiService {
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _storeInfo = {};
  Map<String, dynamic> _businessDetails = {};

  void updateProducts(List<Map<String, dynamic>> products) {
    _products = products;
  }

  void updateStoreInfo(Map<String, dynamic> storeInfo) {
    _storeInfo = storeInfo;
  }

  void updateBusinessDetails(Map<String, dynamic> businessDetails) {
    _businessDetails = businessDetails;
  }

  Future<String> sendMessage(String userMessage) async {
    try {
      // If we have the Gemini API key, use it
      final apiKey = await _getGeminiApiKey();
      
      if (apiKey != null && apiKey.isNotEmpty) {
        return await _sendToGemini(userMessage, apiKey);
      } else {
        // Fallback to local response
        return _generateLocalResponse(userMessage);
      }
    } catch (e) {
      print('Error sending message: $e');
      return _generateLocalResponse(userMessage);
    }
  }

  Future<String?> _getGeminiApiKey() async {
    // Try to get from business details or environment
    return _businessDetails['geminiApiKey'];
  }

  Future<String> _sendToGemini(String userMessage, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': _buildPrompt(userMessage)}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          return text;
        }
      }
      return _generateLocalResponse(userMessage);
    } catch (e) {
      print('Gemini API error: $e');
      return _generateLocalResponse(userMessage);
    }
  }

  String _buildPrompt(String userMessage) {
    String productsInfo = '';
    if (_products.isNotEmpty) {
      productsInfo = 'Products available:\n';
      for (final product in _products.take(20)) {
        final name = product['productName'] ?? 'Unknown';
        final price = product['price'] ?? 'N/A';
        final discount = product['discountPrice'] ?? '';
        final stock = product['quantity'] ?? 'N/A';
        productsInfo += '- $name: Price: $price';
        if (discount.toString().isNotEmpty) {
          productsInfo += ' (Discounted: $discount)';
        }
        productsInfo += ', Stock: $stock\n';
      }
    }

    String storeInfo = '';
    if (_storeInfo.isNotEmpty) {
      storeInfo = 'Store Information:\n';
      if (_storeInfo['storeName'] != null) storeInfo += 'Name: ${_storeInfo['storeName']}\n';
      if (_storeInfo['address'] != null) storeInfo += 'Address: ${_storeInfo['address']}\n';
      if (_storeInfo['email'] != null) storeInfo += 'Email: ${_storeInfo['email']}\n';
      if (_storeInfo['phone'] != null) storeInfo += 'Phone: ${_storeInfo['phone']}\n';
    }

    return '''
You are a helpful customer support assistant for a store called "${_storeInfo['storeName'] ?? 'My Store'}".

$storeInfo
$productsInfo

Customer question: $userMessage

Please provide a helpful, concise response based on the above information. If the customer asks about products, refer to the product list. If they ask about store details, refer to the store information. If they ask about something not in the data, politely say you don't have that information.
''';
  }

  String _generateLocalResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Check for product count
    if (lowerMessage.contains('how many') || lowerMessage.contains('count')) {
      if (_products.isNotEmpty) {
        return 'We currently have ${_products.length} products available in our store. Would you like me to list them?';
      } else {
        return "I'm sorry, but I don't have information about our product count at the moment. Please check back later.";
      }
    }

    // Check for product availability
    if (lowerMessage.contains('available') || lowerMessage.contains('in stock') || lowerMessage.contains('stock')) {
      if (_products.isNotEmpty) {
        final inStock = _products.where((p) {
          final qty = p['quantity'] ?? 0;
          // FIXED: Use > 0 instead of isPositive
          return int.tryParse(qty.toString()) != null && int.tryParse(qty.toString())! > 0;
        });
        if (inStock.isNotEmpty) {
          return 'We have ${inStock.length} products in stock. Here are some: ${inStock.take(5).map((p) => p['productName'] ?? 'Product').join(', ')}... Would you like more details about any specific product?';
        } else {
          return 'I apologize, but it appears we are currently out of stock. Please check back later.';
        }
      }
      return "I'm sorry, but I don't have stock information at the moment.";
    }

    // Check for product listing
    if (lowerMessage.contains('product') || lowerMessage.contains('list') || lowerMessage.contains('show')) {
      if (_products.isNotEmpty) {
        final names = _products.take(10).map((p) => p['productName'] ?? 'Product').join(', ');
        return 'Here are our available products: $names${_products.length > 10 ? ' and ${_products.length - 10} more' : ''}. Would you like to know more about any specific product?';
      }
      return "I'm sorry, but I don't have product information at the moment.";
    }

    // Check for store info
    if (lowerMessage.contains('store') || lowerMessage.contains('shop') || lowerMessage.contains('about')) {
      final name = _storeInfo['storeName'] ?? 'our store';
      final address = _storeInfo['address'] ?? '';
      final phone = _storeInfo['phone'] ?? '';
      final email = _storeInfo['email'] ?? '';
      
      if (name.isNotEmpty || address.isNotEmpty || phone.isNotEmpty || email.isNotEmpty) {
        return 'Store Information:\n$name\n${address.isNotEmpty ? 'Address: $address\n' : ''}${phone.isNotEmpty ? 'Phone: $phone\n' : ''}${email.isNotEmpty ? 'Email: $email' : ''}';
      }
      return "I'm here to help with any questions about our store!";
    }

    // Default response
    return "Thank you for your question! I'm here to help with product information, stock availability, pricing, and store details. Could you please be more specific about what you'd like to know?";
  }
}

class ChatBotPage extends StatefulWidget {
  final String shopName;
  final String appName;

  const ChatBotPage({
    super.key,
    required this.shopName,
    required this.appName,
  });

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _checkingPremium = false;
  bool _isPremium = true;
  bool _isLoadingData = true;
  bool _isSendingMessage = false;

  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final GeminiService _geminiService = GeminiService();

  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _storeInfo = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    bool premium = false;
    try {
      final apiService = ApiService();
      premium = await apiService.hasActiveSubscription();
    } catch (_) {
      premium = false;
    }

    if (!mounted) return;

    setState(() {
      _isPremium = premium;
      _checkingPremium = false;
    });

    // Load product data
    await _loadProductData();

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage.bot(
          "Hi! I'm your ${widget.shopName} assistant. I can help you with product information, stock availability, pricing, and store details. How can I help you today?",
        ),
      );
    });

    _scrollToBottom();
  }

  Future<void> _loadProductData() async {
    try {
      setState(() => _isLoadingData = true);

      final adminId = await AdminManager.getCurrentAdminId();
      print('🔍 Chatbot using admin ID: $adminId');
      print('🌐 API URL: ${ApiConfig.baseUrl}/api/get-form?adminId=$adminId&appId=${ApiConfig.appId}');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/get-form?adminId=$adminId&appId=${ApiConfig.appId}'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');

      Map<String, dynamic> businessDetails = {};
      List<Map<String, dynamic>> extractedProducts = [];
      Map<String, dynamic> storeInfoData = {};

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data: ${data.toString().substring(0, data.toString().length > 500 ? 500 : data.toString().length)}...');
        
        if (data['success'] == true) {
          final pages = (data['pages'] is List) ? List.from(data['pages']) : <dynamic>[];

          if (pages.isNotEmpty && pages.first is Map && (pages.first as Map)['widgets'] is List) {
            final widgets = List<Map<String, dynamic>>.from((pages.first as Map)['widgets']);
            for (final w in widgets) {
              final name = (w['name'] ?? '').toString();
              final props = w['properties'];
              
              if (name == 'ProductGridWidget' || name == 'Catalog View Card' || name == 'Product Detail Card') {
                if (props is Map && props['productCards'] is List) {
                  extractedProducts.addAll(List<Map<String, dynamic>>.from(props['productCards']));
                }
              }
              
              if (name == 'StoreInfoWidget' && props is Map) {
                if (props['storeName'] != null) storeInfoData['storeName'] = props['storeName'];
                if (props['address'] != null) storeInfoData['address'] = props['address'];
                if (props['email'] != null) storeInfoData['email'] = props['email'];
                if (props['phone'] != null) storeInfoData['phone'] = props['phone'];
                if (props['website'] != null) storeInfoData['website'] = props['website'];
                print('📋 Found store info in StoreInfoWidget: $storeInfoData');
              }
            }
          }

          final apiStoreInfo = (data['storeInfo'] is Map) 
              ? Map<String, dynamic>.from(data['storeInfo']) 
              : <String, dynamic>{};
          
          if (storeInfoData.isNotEmpty) {
            print('✅ Using store info from widget properties');
          } else if (apiStoreInfo.isNotEmpty) {
            storeInfoData = apiStoreInfo;
            print('✅ Using store info from API storeInfo field');
          } else {
            storeInfoData = {
              'storeName': data['shopName'] ?? data['appName'],
              'shopName': data['shopName'] ?? data['appName'],
              'appName': data['appName'],
            };
            print('⚠️ storeInfo field not found in API response, using top-level fields');
          }
          
          print('✅ Final store info: $storeInfoData');
          print('🔍 Available API fields: ${data.keys.toList()}');
        } else {
          print('❌ API returned success: false');
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      try {
        final apiService = ApiService();
        businessDetails = await apiService.getBusinessDetails() ?? {};
        print('✅ Business details: $businessDetails');
      } catch (e) {
        print('Error fetching business details: $e');
      }

      if (mounted) {
        setState(() {
          _products = extractedProducts;
          _storeInfo = storeInfoData;
          _isLoadingData = false;
        });

        _geminiService.updateProducts(_products);
        _geminiService.updateStoreInfo(_storeInfo);
        _geminiService.updateBusinessDetails(businessDetails);
        
        print('Loaded ${_products.length} products for chatbot');
        print('Store info: $_storeInfo');
        print('Business details: $businessDetails');
      }
    } catch (e) {
      print('Error loading product data: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSendingMessage) return;

    setState(() {
      _messages.add(_ChatMessage.user(trimmed));
      _isSendingMessage = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final reply = await _geminiService.sendMessage(trimmed);
      
      if (!mounted) return;
      
      setState(() {
        _messages.add(_ChatMessage.bot(reply));
        _isSendingMessage = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error getting AI response: $e');
      if (!mounted) return;
      
      setState(() {
        _messages.add(_ChatMessage.bot(
          'I apologize, but I encountered an error. Please try again.'
        ));
        _isSendingMessage = false;
      });
      _scrollToBottom();
    }
  }

  List<String> get _quickReplies => <String>[
        'How many products do you have?',
        'What products are available?',
        'Check stock availability',
        'Tell me about your store',
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.shopName} Support'),
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading product data...'),
                ],
              ),
            )
          : _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: _messages.length + (_isSendingMessage ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isSendingMessage) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Thinking...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final m = _messages[index];
              return Align(
                alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: m.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickReplies
                  .map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _send(q),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _isSendingMessage ? null : _send,
                    enabled: !_isSendingMessage,
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSendingMessage ? null : () => _send(_controller.text),
                  icon: _isSendingMessage 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String text;

  const _ChatMessage._(this.isUser, this.text);

  factory _ChatMessage.user(String text) => _ChatMessage._(true, text);
  factory _ChatMessage.bot(String text) => _ChatMessage._(false, text);
}
