/**
 * Base Tool Interface
 * Class abstrak untuk semua agent tools
 */

import type { ToolResult } from '../types.ts';

export interface ToolParams {
  [key: string]: unknown;
}

export abstract class BaseTool {
  abstract name: string;
  abstract description: string;
  abstract intents: string[]; // Intent yang ditangani tool ini

  abstract execute(params: ToolParams): Promise<ToolResult>;

  protected success(data: unknown, message: string): ToolResult {
    return { success: true, data, message };
  }

  protected error(message: string, errorDetail?: string): ToolResult {
    return { success: false, message, error: errorDetail };
  }
}

/**
 * Tool Registry
 * Mengelola dan mencari tools berdasarkan nama atau intent
 */
export class ToolRegistry {
  private tools: Map<string, BaseTool> = new Map();
  private intentMap: Map<string, BaseTool> = new Map();

  register(tool: BaseTool): void {
    this.tools.set(tool.name, tool);

    // Map intent ke tool
    for (const intent of tool.intents) {
      this.intentMap.set(intent, tool);
    }

    console.log(`Tool terdaftar: ${tool.name} untuk intent: ${tool.intents.join(', ')}`);
  }

  get(name: string): BaseTool | undefined {
    return this.tools.get(name);
  }

  getForIntent(intent: string): BaseTool | undefined {
    return this.intentMap.get(intent);
  }

  list(): BaseTool[] {
    return Array.from(this.tools.values());
  }
}
