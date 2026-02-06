import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/voice_service.dart';
import '../services/command_router.dart';
import '../services/context_service.dart';
import '../models/command_action.dart';

enum AssistantState {
  idle,
  listening,
  thinking,
  executing,
  showingPanel,
  error,
}

class AssistantController extends ChangeNotifier {
  final ApiClient apiClient;
  final VoiceService voiceService;
  final ContextService contextService;
  
  AssistantState _state = AssistantState.idle;
  String _currentCommand = '';
  CommandAction? _currentAction;
  String? _error;
  List<String> _reasoningSteps = [];
  String _partialVoiceInput = '';
  
  AssistantController({
    required this.apiClient,
    required this.voiceService,
    required this.contextService,
  });
  
  // Getters
  AssistantState get state => _state;
  String get currentCommand => _currentCommand;
  CommandAction? get currentAction => _currentAction;
  String? get error => _error;
  List<String> get reasoningSteps => _reasoningSteps;
  String get partialVoiceInput => _partialVoiceInput;
  
  bool get isLoading => 
      _state == AssistantState.listening ||
      _state == AssistantState.thinking ||
      _state == AssistantState.executing;
  
  // Process command with smart routing
  Future<void> processCommand(String command) async {
    if (command.trim().isEmpty) return;
    
    _currentCommand = command;
    _currentAction = null;
    _error = null;
    _reasoningSteps = [];
    
    try {
      // Route command
      final route = CommandRouter.route(command);
      
      print('🔵 Command: $command');
      print('🔵 Route type: ${route.type}');
      print('🔵 Reason: ${route.reason}');
      
      switch (route.type) {
        case RouteType.directApi:
          await _handleDirectApi(route);
          break;
          
        case RouteType.localPanel:
          await _handleLocalPanel(route);
          break;
          
        case RouteType.aiAgent:
          await _handleAiAgent(command);
          break;
      }
      
    } catch (e) {
      print('🔴 Process command error: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _setState(AssistantState.error);
      
      // Record error in context
      contextService.recordError(_error!);
      
      // Auto-reset to idle after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (_state == AssistantState.error) {
          reset();
        }
      });
    }
  }
  
  // Handle direct API call (no AI)
  Future<void> _handleDirectApi(CommandRoute route) async {
    _setState(AssistantState.thinking);
    _reasoningSteps = ['Fetching data...'];
    notifyListeners();
    
    // Call API directly
    final response = await apiClient.get(route.apiEndpoint!);
    
    print('🔵 Direct API response: $response');
    
    // Create action with data
    _currentAction = CommandAction(
      type: route.action,
      data: response['data'] ?? response,
      summary: null,
      rawMessage: null,
    );
    
    // Record successful command
    contextService.recordCommand(_currentCommand);
    
    _setState(AssistantState.showingPanel);
  }
  
  // Handle local panel (no API, just show UI)
  Future<void> _handleLocalPanel(CommandRoute route) async {
    // Show panel immediately with parsed data
    _currentAction = CommandAction(
      type: route.action,
      data: route.params ?? {},
      summary: null,
      rawMessage: null,
    );
    
    // Record successful command
    contextService.recordCommand(_currentCommand);
    
    _setState(AssistantState.showingPanel);
  }
  
  // Handle AI agent (complex reasoning) - WITH STREAMING
  Future<void> _handleAiAgent(String command) async {
    _setState(AssistantState.thinking);
    _reasoningSteps = [
      'Analyzing command...',
    ];
    notifyListeners();
    
    String accumulatedText = '';
    List<String> toolsUsed = [];
    Map<String, dynamic>? structuredDoneEvent;
    
    try {
      // Try streaming first
      try {
        await for (final chunk in apiClient.sendMessageStream(command)) {
          // Check if it's a tool marker
          if (chunk.startsWith('[Using ')) {
            // Tool call started
            final toolName = chunk.replaceAll('[Using ', '').replaceAll('...]', '').trim();
            toolsUsed.add(toolName);
            
            _reasoningSteps = [
              'Analyzing command...',
              'Using tools: ${toolsUsed.join(", ")}',
              'Processing...',
            ];
            notifyListeners();
          } else if (chunk.startsWith('[✓ ')) {
            // Tool completed
            _reasoningSteps = [
              'Analyzing command...',
              'Tools used: ${toolsUsed.join(", ")}',
              'Receiving response...',
            ];
            notifyListeners();
          } else if (chunk.startsWith('___DONE___')) {
            // Structured done event from backend
            final doneJson = chunk.substring(10); // Remove '___DONE___' prefix
            try {
              structuredDoneEvent = jsonDecode(doneJson);
              print('🔵 Received structured done event');
            } catch (e) {
              print('🔴 Failed to parse done event: $e');
            }
          } else {
            // Regular text chunk - accumulate for fallback
            accumulatedText += chunk;
          }
          
          print('🔵 Chunk received: ${chunk.length} chars');
        }
      } catch (streamError) {
        print('🔴 Streaming failed: $streamError');
        print('🔵 Falling back to non-streaming API...');
        
        // Fallback to non-streaming
        _reasoningSteps = [
          'Analyzing command...',
          'Processing request...',
        ];
        notifyListeners();
        
        final response = await apiClient.sendMessage(command);
        
        // Non-streaming response is already structured
        _currentAction = CommandAction.fromApiResponse(response);
        
        print('🔵 Non-streaming Action Type: ${_currentAction!.type}');
        print('🔵 Non-streaming Summary: ${_currentAction!.summary}');
        
        // Record successful command
        contextService.recordCommand(command);
        
        // Show panel
        _setState(AssistantState.showingPanel);
        return;
      }
      
      // Parse final response from structured done event or fallback
      if (structuredDoneEvent != null) {
        // Use structured done event directly
        print('🔵 Using structured done event');
        _currentAction = CommandAction.fromStreamDoneEvent(structuredDoneEvent);
      } else if (accumulatedText.isNotEmpty) {
        // Fallback: try to parse accumulated text
        print('🔵 Using accumulated text fallback');
        Map<String, dynamic> response;
        try {
          response = jsonDecode(accumulatedText);
        } catch (e) {
          // If not JSON, treat as plain text response
          print('🔵 Response is plain text, not JSON');
          response = {
            'success': true,
            'data': {
              'actionType': 'info',
              'status': 'success',
              'summary': _extractSummary(accumulatedText),
              'details': {},
              'rawMessage': accumulatedText,
              'toolsUsed': toolsUsed,
            },
          };
        }
        
        // Check if response is successful
        if (response['success'] == false) {
          final errorMsg = response['error']?.toString() ?? 'Request failed';
          throw Exception(errorMsg);
        }
        
        // Parse action from response
        _currentAction = CommandAction.fromApiResponse(response);
      } else {
        throw Exception('No response from AI. Please try a different command or check your connection.');
      }
      
      print('🔵 Action Type: ${_currentAction!.type}');
      print('🔵 Summary: ${_currentAction!.summary}');
      
      // Record successful command
      contextService.recordCommand(command);
      
      // Show panel
      _setState(AssistantState.showingPanel);
      
    } catch (e) {
      print('🔴 AI Agent error: $e');
      
      // Extract clean error message
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Provide more helpful error messages
      if (errorMessage.contains('400') || errorMessage.contains('Bad Request')) {
        errorMessage = 'Invalid request. The AI service couldn\'t process this command. Try rephrasing it.';
      } else if (errorMessage.contains('401') || errorMessage.contains('Unauthorized')) {
        errorMessage = 'Authentication failed. Please login again.';
      } else if (errorMessage.contains('500') || errorMessage.contains('Internal Server')) {
        errorMessage = 'Server error. The AI service is having issues. Please try again later.';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (errorMessage.contains('Network Error') || errorMessage.contains('Cannot connect')) {
        errorMessage = 'Cannot connect to server. Check your internet connection.';
      }
      
      _error = errorMessage;
      _setState(AssistantState.error);
      
      // Auto-reset to idle after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (_state == AssistantState.error) {
          reset();
        }
      });
    }
  }
  
  // Extract short summary from text
  String _extractSummary(String text) {
    final sentences = text.split('. ');
    if (sentences.isNotEmpty) {
      final first = sentences.first.trim();
      return first.length > 100 ? '${first.substring(0, 100)}...' : first;
    }
    return text.length > 100 ? '${text.substring(0, 100)}...' : text;
  }
  
  void _setState(AssistantState newState) {
    _state = newState;
    notifyListeners();
  }
  
  void reset() {
    _state = AssistantState.idle;
    _currentCommand = '';
    _currentAction = null;
    _error = null;
    _reasoningSteps = [];
    notifyListeners();
  }
  
  void dismissPanel() {
    _setState(AssistantState.idle);
    _currentAction = null;
    notifyListeners();
  }
  
  void startVoiceInput() async {
    try {
      _setState(AssistantState.listening);
      _partialVoiceInput = '';
      
      await voiceService.startListening(
        onResult: (text) {
          // Final result - process command
          _currentCommand = text;
          _partialVoiceInput = '';
          processCommand(text);
        },
        onPartialResult: (text) {
          // Partial result - update UI
          _partialVoiceInput = text;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Voice input failed: ${e.toString()}';
      _setState(AssistantState.error);
      
      Future.delayed(const Duration(seconds: 3), () {
        if (_state == AssistantState.error) {
          reset();
        }
      });
    }
  }
  
  void stopVoiceInput() async {
    await voiceService.stopListening();
    if (_state == AssistantState.listening) {
      _setState(AssistantState.idle);
    }
  }
  
  void cancelVoiceInput() async {
    await voiceService.cancelListening();
    _partialVoiceInput = '';
    _setState(AssistantState.idle);
  }
}
