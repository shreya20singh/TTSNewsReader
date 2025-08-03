/**
 * Text-to-Speech Node with Spanish Translation
 * 
 * This file implements a graph that can optionally translate text to Spanish
 * before sending it to the TTS engine. The graph structure is:
 * 
 * [Input] -> [Translation (optional)] -> [TTS] -> [Output]
 * 
 * When translation is enabled, the input text is first sent to an LLM that
 * translates it to Spanish, and then the translated text is sent to the TTS engine.
 * When translation is disabled, the input text is sent directly to the TTS engine.
 */

import 'dotenv/config';

import * as fs from 'fs';
import * as path from 'path';
import { v4 } from 'uuid';

const minimist = require('minimist');
const wavEncoder = require('wav-encoder');

// Import necessary interfaces and types from Inworld runtime
import { 
  ContentInterface,      // For handling LLM response content
  ContentStreamIterator, // For streaming LLM content
  LLMChatRequestInterface, // For creating LLM requests
  TTSOutputStreamIterator // For streaming TTS audio
} from '@inworld/runtime/common';
import {
  AudioResponse,
  ComponentFactory,
  GraphBuilder,
  NodeFactory,
} from '@inworld/runtime/graph';

import {
  DEFAULT_LLM_MODEL_NAME, // Default LLM model for translation
  DEFAULT_TTS_MODEL_ID,   // Default TTS model
  DEFAULT_VOICE_ID,       // Default voice ID
  SAMPLE_RATE,            // Audio sample rate
  TEXT_CONFIG,            // Text generation configuration
} from '../constants';
import { bindProcessHandlers, cleanup } from '../helpers/cli_helpers';

const OUTPUT_DIRECTORY = path.join(
  __dirname,
  '..',
  '..',
  'data-output',
  'tts_samples',
);
const OUTPUT_PATH = path.join(OUTPUT_DIRECTORY, 'node_tts_output.wav');

const usage = `
Usage:
    yarn node-tts "Hello, how can I help you?" \n
    --modelId=<model-id>[optional, ${DEFAULT_TTS_MODEL_ID} will be used by default] \n
    --voiceName=<voice-id>[optional, ${DEFAULT_VOICE_ID} will be used by default] \n
    --llmModelName=<llm-model-name>[optional, ${DEFAULT_LLM_MODEL_NAME} will be used by default] \n
    --translate=<true|false>[optional, default=true, enable/disable Spanish translation]`;

/**
 * Main execution function that sets up and runs the graph
 */
async function run() {
  // Parse command line arguments
  const { text, modelId, voiceName, apiKey, llmModelName, translate } = parseArgs();

  // Create TTS component for speech synthesis
  const ttsComponent = ComponentFactory.createRemoteTTSComponent({
    id: 'tts_component',
    apiKey,
    synthesisConfig: {
      type: 'inworld',
      config: {
        modelId,
        postprocessing: {
          sampleRate: SAMPLE_RATE,
        },
        inference: {
          pitch: 0,          // Neutral pitch
          speakingRate: 1,   // Normal speaking rate
          temperature: 0.8,  // Moderate temperature for natural-sounding speech
        },
      },
    },
  });

  // Create TTS node that will convert text to speech
  const ttsNode = NodeFactory.createRemoteTTSNode({
    id: 'tts_node',
    ttsComponentId: ttsComponent.id,
    voice: {
      speakerId: voiceName,  // Use the specified voice
    },
  });
  
  // Create input and output proxy nodes for the graph
  // These nodes serve as entry and exit points for the graph
  const inputProxyNode = NodeFactory.createProxyNode({
    id: 'input',
    reportToClient: false,  // Don't report input node events to client
  });

  const outputProxyNode = NodeFactory.createProxyNode({
    id: 'output',
    reportToClient: false,  // Don't report output node events to client
  });
  
  let executor;
  let graphInput: string | LLMChatRequestInterface = text;
  
  if (translate) {
    // Translation is enabled - first translate the text using LLM, then use TTS
    console.log('🔄 Translation enabled. Original text:', text);
    
    // Step 1: Create a separate graph just for translation
    const translationLLMNode = NodeFactory.createRemoteLLMChatNode({
      id: 'translation_llm_node',
      llmConfig: {
        provider: 'inworld',        // Use Inworld as the LLM provider
        modelName: llmModelName,   // Use specified LLM model
        apiKey,                    // API key for authentication
        stream: false,             // Disable streaming for simplicity
        textGenerationConfig: TEXT_CONFIG,  // Use default text generation config
      },
    });
    
    const translationInputNode = NodeFactory.createProxyNode({
      id: 'translation_input',
      reportToClient: false,
    });
    
    const translationOutputNode = NodeFactory.createProxyNode({
      id: 'translation_output',
      reportToClient: false,
    });
    
    // Build a simple translation graph
    const translationExecutor = new GraphBuilder('translation_graph')
      .addNode(translationInputNode)
      .addNode(translationLLMNode)
      .addNode(translationOutputNode)
      .addEdge(translationInputNode, translationLLMNode)
      .addEdge(translationLLMNode, translationOutputNode)
      .setStartNode(translationInputNode)
      .setEndNode(translationOutputNode)
      .getExecutor();
    
    // Execute translation graph with translation prompt
    const translationPrompt = createTranslationPrompt(text);
    const translationStream = await translationExecutor.execute(translationPrompt, v4());
    
    // Get translation result
    const translationResult = await translationStream.next();
    let translatedText = '';
    
    if (translationResult.type === 'CONTENT') {
      // Handle non-streaming LLM response
      const response = translationResult.data as ContentInterface;
      translatedText = response.content;
      console.log('📥 Translation Result:', translatedText);
    } else if (translationResult.type === 'CONTENT_STREAM') {
      // Handle streaming LLM response
      const streamIterator = translationResult.data as ContentStreamIterator;
      
      // Collect all chunks from the stream
      while (true) {
        const chunk = await streamIterator.next();
        if (chunk.done) {
          break;
        }
        
        if (chunk.text) {
          translatedText += chunk.text;
        }
      }
      
      console.log('📡 Translation Result:', translatedText);
    }
    
    // Clean up translation resources
    cleanup(translationExecutor, translationStream);
    
    // Step 2: Now create a TTS graph with the translated text
    console.log('🔊 Creating TTS for translated text');
    
    // The flow is: input -> TTS -> output
    executor = new GraphBuilder('node_tts_graph')
      .addComponent(ttsComponent)        // Add TTS component to the graph
      .addNode(inputProxyNode)           // Add input node
      .addNode(ttsNode)                  // Add TTS node
      .addNode(outputProxyNode)          // Add output node
      .addEdge(inputProxyNode, ttsNode)  // Connect input to TTS
      .addEdge(ttsNode, outputProxyNode) // Connect TTS to output
      .setStartNode(inputProxyNode)      // Set input as start node
      .setEndNode(outputProxyNode)       // Set output as end node
      .getExecutor();                    // Get the executor
    
    // Use the translated text as input to the TTS graph
    graphInput = translatedText;
  } else {
    // Translation is disabled - build graph with just TTS
    console.log('🔊 Translation disabled. Using original text for TTS.');
    
    // The flow is: input -> TTS -> output
    executor = new GraphBuilder('node_tts_graph')
      .addComponent(ttsComponent)        // Add TTS component to the graph
      .addNode(inputProxyNode)           // Add input node
      .addNode(ttsNode)                  // Add TTS node
      .addNode(outputProxyNode)          // Add output node
      .addEdge(inputProxyNode, ttsNode)  // Connect input to TTS
      .addEdge(ttsNode, outputProxyNode) // Connect TTS to output
      .setStartNode(inputProxyNode)      // Set input as start node
      .setEndNode(outputProxyNode)       // Set output as end node
      .getExecutor();                    // Get the executor
  }

  // Execute the graph with the appropriate input
  const outputStream = await executor.execute(graphInput, v4());
  
  // We don't need to handle translation result here anymore since we're using a two-graph approach
  // and the translation is already done before this point
  
  // Get TTS stream from the TTS node
  const ttsResult = await outputStream.next();
  const ttsStream = ttsResult.data as TTSOutputStreamIterator;

  let initialText = '';
  let resultCount = 0;
  let allAudioData: number[] = [];

  let chunk: AudioResponse = await ttsStream.next();

  while (!chunk.done) {
    initialText += chunk.text;
    allAudioData = allAudioData.concat(Array.from(chunk.audio.data));
    resultCount++;

    chunk = await ttsStream.next();
  }

  console.log(`Result count: ${resultCount}`);
  console.log(`Initial text: ${initialText}`);

  // Create a single audio object with all the data
  const audio = {
    sampleRate: SAMPLE_RATE, // default sample rate
    channelData: [new Float32Array(allAudioData)],
  };

  // Encode and write all the audio data to a single file
  const buffer = await wavEncoder.encode(audio);
  if (!fs.existsSync(OUTPUT_DIRECTORY)) {
    fs.mkdirSync(OUTPUT_DIRECTORY, { recursive: true });
  }

  fs.writeFileSync(OUTPUT_PATH, Buffer.from(buffer));

  console.log(`Audio saved to ${OUTPUT_PATH}`);

  cleanup(executor, outputStream);
}

/**
 * Creates a translation prompt for the LLM
 * @param text - The text to translate to Spanish
 * @returns An LLM chat request with system and user messages
 */
function createTranslationPrompt(text: string): LLMChatRequestInterface {
  // System message instructs the LLM to act as a translation assistant
  const systemMessage = {
    role: 'system',
    content: 'You are a translation assistant. Translate the given text to Spanish. Only respond with the translated text, nothing else.',
  };
  
  // User message contains the text to translate
  const userMessage = {
    role: 'user',
    content: text,
  };
  
  // Return the messages in the format expected by the LLM
  return {
    messages: [systemMessage, userMessage],
  };
}

/**
 * Parse command line arguments
 * @returns Parsed arguments object
 */
function parseArgs(): {
  text: string;
  modelId: string;
  voiceName: string;
  apiKey: string;
  llmModelName: string;
  translate: boolean;
} {
  const argv = minimist(process.argv.slice(2));

  if (argv.help) {
    console.log(usage);
    process.exit(0);
  }

  // Parse command line arguments with defaults
  const text = argv._?.join(' ') || '';
  const modelId = argv.modelId || DEFAULT_TTS_MODEL_ID;
  const voiceName = argv.voiceName || DEFAULT_VOICE_ID;
  const llmModelName = argv.llmModelName || DEFAULT_LLM_MODEL_NAME;
  // Translation is always enabled by default
  const translate = true;
  const apiKey = process.env.INWORLD_API_KEY || '';

  if (!text) {
    throw new Error(`You need to provide text.\n${usage}`);
  }

  if (!apiKey) {
    throw new Error(
      `You need to set INWORLD_API_KEY environment variable.\n${usage}`,
    );
  }

  return { text, modelId, voiceName, apiKey, llmModelName, translate };
}

bindProcessHandlers();

// Execute the main function
run();
