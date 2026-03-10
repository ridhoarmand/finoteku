/**
 * Base Tool dan Registry
 * Class dasar untuk semua agent tools
 */

import type { ToolResult } from '../../types.ts';

/**
 * Parameter yang diterima tool saat execute
 */
export interface ToolParams {
  [key: string]: unknown;
}

/**
 * Class abstrak untuk semua tools
 * Setiap tool harus extend class ini dan implement execute()
 */
export abstract class BaseTool {
  /** Nama unik tool */
  abstract name: string;

  /** Deskripsi fungsi tool */
  abstract description: string;

  /** Intent yang ditangani tool ini */
  abstract intents: string[];

  /**
   * Execute fungsi utama tool
   */
  abstract execute(params: ToolParams): Promise<ToolResult>;

  /**
   * Return hasil sukses
   */
  protected success(data: unknown, message: string): ToolResult {
    return { success: true, data, message };
  }

  /**
   * Return hasil error
   */
  protected error(message: string, errorDetail?: string): ToolResult {
    return { success: false, message, error: errorDetail };
  }
}

/**
 * Registry untuk manage semua tools
 * Bisa lookup by name atau by intent
 */
export class ToolRegistry {
  private tools: Map<string, BaseTool> = new Map();
  private intentMap: Map<string, BaseTool> = new Map();

  /**
   * Daftarkan tool baru
   */
  register(tool: BaseTool): void {
    this.tools.set(tool.name, tool);

    for (const intent of tool.intents) {
      this.intentMap.set(intent, tool);
    }

    console.log(`✅ Tool terdaftar: ${tool.name} → [${tool.intents.join(', ')}]`);
  }

  /**
   * Ambil tool by name
   */
  get(name: string): BaseTool | undefined {
    return this.tools.get(name);
  }

  /**
   * Ambil tool by intent
   */
  getForIntent(intent: string): BaseTool | undefined {
    return this.intentMap.get(intent);
  }

  /**
   * List semua tools
   */
  list(): BaseTool[] {
    return Array.from(this.tools.values());
  }
}
