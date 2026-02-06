import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/voice_service.dart';
import '../services/command_router.dart';
import '../services/context_service.dart';
import '../models/command_action.dart';
import '../models/ai_process_step.dart';

enum AssistantState {
  idle,
  listening,
  thinking,
  executing,
  completing, // New state: showing 100% with summary before panel
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
  List<AIProcessStep> _processSteps = [];
  String _partialVoiceInput = '';
  double _progress = 0.0;
  String _currentPhase = '';
  String? _completionSummary; // Summary to show during completing state
  
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
  List<AIProcessStep> get processSteps => _processSteps;
  String get partialVoiceInput => _partialVoiceInput;
  double get progress => _progress;
  String get currentPhase => _currentPhase;
  String? get completionSummary => _completionSummary;
  
  // Legacy getter for compatibility
  List<String> get reasoningSteps => 
      _processSteps.map((s) => s.title).toList();
  
  bool get isLoading => 
      _state == AssistantState.listening ||
      _state == AssistantState.thinking ||
      _state == AssistantState.executing ||
      _state == AssistantState.completing;
  
  // Add process step
  void _addStep(AIProcessStep step) {
    _processSteps.add(step);
    notifyListeners();
  }
  
  // Update step status
  void _updateStep(String id, StepStatus status, {Map<String, dynamic>? result}) {
    final index = _processSteps.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _processSteps[index] = _processSteps[index].copyWith(
        status: status,
        result: result,
      );
      notifyListeners();
    }
  }
  
  // Set progress and phase
  void _setProgress(double value, String phase) {
    _progress = value.clamp(0.0, 1.0);
    _currentPhase = phase;
    notifyListeners();
  }
  
  // Transition to completing state with summary, then show panel after delay
  Future<void> _completeWithSummary(String? summary) async {
    // Set to completing state with summary
    _completionSummary = summary ?? 'Task completed';
    _setProgress(1.0, 'Complete');
    _setState(AssistantState.completing);
    
    // Wait 300ms to show the completion animation
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Then show the panel
    if (_state == AssistantState.completing) {
      _setState(AssistantState.showingPanel);
    }
  }
  
  // Process command with smart routing
  Future<void> processCommand(String command) async {
    if (command.trim().isEmpty) return;
    
    _currentCommand = command;
    _currentAction = null;
    _error = null;
    _processSteps = [];
    _progress = 0.0;
    _currentPhase = '';
    
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
    
    _addStep(AIProcessStep(
      id: 'fetch',
      type: StepType.tool,
      title: 'Fetching data...',
      status: StepStatus.running,
    ));
    _setProgress(0.3, 'Fetching');
    
    // Call API directly
    final response = await apiClient.get(route.apiEndpoint!);
    
    _updateStep('fetch', StepStatus.completed);
    
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
    
    // Complete with summary and transition
    await _completeWithSummary('Data fetched successfully');
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
  
  // Handle AI agent (complex reasoning) - WITH STREAMING & REAL-TIME STEPS
  Future<void> _handleAiAgent(String command) async {
    _setState(AssistantState.thinking);
    _setProgress(0.1, 'Analyzing');
    
    // Initial thinking step
    _addStep(AIProcessStep(
      id: 'analyze',
      type: StepType.thinking,
      title: 'Analyzing your request...',
      description: _getCommandContext(command),
      status: StepStatus.running,
    ));
    
    String accumulatedText = '';
    List<String> toolsUsed = [];
    Map<String, dynamic>? structuredDoneEvent;
    int toolIndex = 0;
    
    try {
      // Try streaming first
      try {
        await for (final chunk in apiClient.sendMessageStream(command)) {
          // Check if it's a tool marker
          if (chunk.startsWith('[Using ')) {
            // Tool call started
            final toolName = chunk.replaceAll('[Using ', '').replaceAll('...]', '').trim();
            toolsUsed.add(toolName);
            toolIndex++;
            
            // Mark analyze as complete
            _updateStep('analyze', StepStatus.completed);
            
            // Add tool step
            final stepId = 'tool_$toolIndex';
            _addStep(AIProcessStep(
              id: stepId,
              type: StepType.tool,
              title: toolName,
              description: 'Executing...',
              status: StepStatus.running,
            ));
            
            _setProgress(0.2 + (toolIndex * 0.15), 'Calling $toolName');
            
          } else if (chunk.startsWith('[✓ ')) {
            // Tool completed
            final toolName = chunk.replaceAll('[✓ ', '').replaceAll(']', '').trim();
            final stepId = 'tool_$toolIndex';
            
            _updateStep(stepId, StepStatus.completed);
            _setProgress(0.3 + (toolIndex * 0.15), '$toolName completed');
            
          } else if (chunk.startsWith('[Tool Error:')) {
            // Tool failed
            final stepId = 'tool_$toolIndex';
            _updateStep(stepId, StepStatus.failed);
            
          } else if (chunk.startsWith('___REASONING___')) {
            // Reasoning step from AI
            final reasoningText = chunk.substring(15).trim();
            _addStep(AIProcessStep(
              id: 'reasoning_${DateTime.now().millisecondsSinceEpoch}',
              type: StepType.reasoning,
              title: reasoningText,
              status: StepStatus.completed,
            ));
            
          } else if (chunk.startsWith('___DONE___')) {
            // Structured done event from backend
            final doneJson = chunk.substring(10); // Remove '___DONE___' prefix
            try {
              structuredDoneEvent = jsonDecode(doneJson);
              print('🔵 Received structured done event');
              
              // Add final result step
              _addStep(AIProcessStep(
                id: 'result',
                type: StepType.result,
                title: 'Processing complete',
                description: structuredDoneEvent?['summary'] as String?,
                status: StepStatus.completed,
              ));
              _setProgress(1.0, 'Complete');
              
            } catch (e) {
              print('🔴 Failed to parse done event: $e');
            }
          } else if (chunk.isNotEmpty && !chunk.startsWith('[')) {
            // Regular text chunk - accumulate for fallback
            accumulatedText += chunk;
          }
          
          print('🔵 Chunk received: ${chunk.length} chars');
        }
      } catch (streamError) {
        print('🔴 Streaming failed: $streamError');
        print('🔵 Falling back to non-streaming API...');
        
        // Fallback to non-streaming
        _updateStep('analyze', StepStatus.completed);
        
        _addStep(AIProcessStep(
          id: 'fallback',
          type: StepType.tool,
          title: 'Processing request...',
          status: StepStatus.running,
        ));
        _setProgress(0.5, 'Processing');
        
        final response = await apiClient.sendMessage(command);
        
        _updateStep('fallback', StepStatus.completed);
        
        // Non-streaming response is already structured
        _currentAction = CommandAction.fromApiResponse(response);
        
        print('🔵 Non-streaming Action Type: ${_currentAction!.type}');
        print('🔵 Non-streaming Summary: ${_currentAction!.summary}');
        
        // Record successful command
        contextService.recordCommand(command);
        
        // Complete with summary and transition
        await _completeWithSummary(_currentAction?.summary);
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
        
        // Mark processing complete
        _addStep(AIProcessStep(
          id: 'result',
          type: StepType.result,
          title: 'Processing complete',
          status: StepStatus.completed,
        ));
        
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
      
      // Complete with summary and transition
      await _completeWithSummary(_currentAction?.summary);
      
    } catch (e) {
      print('🔴 AI Agent error: $e');
      
      // Add error step
      _addStep(AIProcessStep(
        id: 'error',
        type: StepType.error,
        title: 'Error occurred',
        description: e.toString(),
        status: StepStatus.failed,
      ));
      
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
  
  // Get context description for the command
  String _getCommandContext(String command) {
    final lower = command.toLowerCase();
    
    if (lower.contains('balance') || lower.contains('saldo')) {
      return 'Checking wallet balance...';
    }
    if (lower.contains('swap') || lower.contains('tukar')) {
      return 'Preparing token swap...';
    }
    if (lower.contains('send') || lower.contains('kirim') || lower.contains('transfer')) {
      return 'Preparing transfer...';
    }
    if (lower.contains('stake') || lower.contains('staking')) {
      return 'Checking staking options...';
    }
    if (lower.contains('wallet') || lower.contains('dompet')) {
      return 'Managing wallets...';
    }
    if (lower.contains('nft')) {
      return 'Looking up NFTs...';
    }
    if (lower.contains('price') || lower.contains('harga')) {
      return 'Fetching price data...';
    }
    
    return 'Understanding your intent...';
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
    _processSteps = [];
    _progress = 0.0;
    _currentPhase = '';
    _completionSummary = null;
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
