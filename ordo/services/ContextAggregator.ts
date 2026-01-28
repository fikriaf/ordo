/**
 * Context Aggregator Service
 *
 * Combines results from multiple surfaces (Gmail, X, Telegram, Wallet)
 * with source attribution tracking and cross-surface data merging.
 *
 * Validates: Requirements 7.3, 9.1, 9.2, 9.4, 9.6
 */

export enum Surface {
  GMAIL = 'GMAIL',
  X = 'X',
  TELEGRAM = 'TELEGRAM',
  WALLET = 'WALLET',
  WEB = 'WEB',
}

export interface Source {
  surface: Surface;
  identifier: string; // email ID, tweet ID, transaction signature, etc.
  timestamp: Date;
  preview: string;
}

export interface SurfaceData {
  surface: Surface;
  data: any;
  timestamp: Date;
  itemCount: number;
}

export interface ContextMetadata {
  totalSurfaces: number;
  totalItems: number;
  aggregatedAt: Date;
  hasConflicts: boolean;
}

export interface AggregatedContext {
  surfaces: SurfaceData[];
  combinedText: string;
  sources: Source[];
  metadata: ContextMetadata;
}

export interface ToolResult {
  success: boolean;
  data?: any;
  error?: string;
  filteredCount?: number;
  surface?: Surface;
  toolName?: string;
}

export class ContextAggregator {
  /**
   * Combine results from multiple tool executions.
   *
   * Aggregates data from multiple surfaces while maintaining
   * source attribution and handling conflicts.
   *
   * @param results - Array of tool results from different surfaces
   * @returns Aggregated context with combined data and sources
   *
   * Validates: Requirements 7.3, 9.2
   */
  async aggregateResults(results: ToolResult[]): Promise<AggregatedContext> {
    const surfaces: SurfaceData[] = [];
    const sources: Source[] = [];
    let totalItems = 0;
    let hasConflicts = false;

    // Process each result
    for (const result of results) {
      if (!result.success || !result.data) {
        continue;
      }

      const surface = result.surface || this.inferSurface(result.toolName || '');
      const timestamp = new Date();

      // Extract items from result
      const items = Array.isArray(result.data) ? result.data : [result.data];
      const itemCount = items.length;
      totalItems += itemCount;

      // Add surface data
      surfaces.push({
        surface,
        data: result.data,
        timestamp,
        itemCount,
      });

      // Extract sources from items
      const itemSources = this.extractSourcesFromData(items, surface);
      sources.push(...itemSources);
    }

    // Check for conflicts (e.g., duplicate information from different surfaces)
    hasConflicts = this.detectConflicts(surfaces);

    // Combine text from all surfaces
    const combinedText = this.combineText(surfaces);

    return {
      surfaces,
      combinedText,
      sources,
      metadata: {
        totalSurfaces: surfaces.length,
        totalItems,
        aggregatedAt: new Date(),
        hasConflicts,
      },
    };
  }

  /**
   * Format aggregated context for LLM consumption.
   *
   * Converts aggregated context into a formatted string
   * suitable for inclusion in LLM prompts.
   *
   * @param context - Aggregated context
   * @returns Formatted context string
   *
   * Validates: Requirements 7.3
   */
  formatForLLM(context: AggregatedContext): string {
    let formatted = 'Context from multiple sources:\n\n';

    // Add data from each surface
    for (const surfaceData of context.surfaces) {
      formatted += `[${surfaceData.surface}] (${surfaceData.itemCount} items):\n`;
      formatted += this.formatSurfaceData(surfaceData);
      formatted += '\n\n';
    }

    // Add metadata
    formatted += `Aggregated from ${context.metadata.totalSurfaces} surfaces, `;
    formatted += `${context.metadata.totalItems} total items.\n`;

    if (context.metadata.hasConflicts) {
      formatted += 'Note: Some information may be duplicated across surfaces.\n';
    }

    return formatted;
  }

  /**
   * Extract source citations from aggregated context.
   *
   * Extracts all source citations for display in UI
   * and for inline citation in responses.
   *
   * @param context - Aggregated context
   * @returns Array of sources
   *
   * Validates: Requirements 7.5, 9.4, 10.6
   */
  extractSources(context: AggregatedContext): Source[] {
    return context.sources;
  }

  /**
   * Merge data from multiple surfaces with source attribution.
   *
   * Combines data while maintaining source attribution,
   * handling duplicates and conflicts.
   *
   * @param surfaceDataList - List of surface data to merge
   * @returns Merged data with source attribution
   *
   * Validates: Requirements 9.2, 9.4
   */
  mergeWithAttribution(surfaceDataList: SurfaceData[]): any[] {
    const merged: any[] = [];
    const seen = new Set<string>();

    for (const surfaceData of surfaceDataList) {
      const items = Array.isArray(surfaceData.data)
        ? surfaceData.data
        : [surfaceData.data];

      for (const item of items) {
        // Create unique key for deduplication
        const key = this.createItemKey(item, surfaceData.surface);

        if (!seen.has(key)) {
          // Add source attribution to item
          merged.push({
            ...item,
            _source: {
              surface: surfaceData.surface,
              timestamp: surfaceData.timestamp,
            },
          });
          seen.add(key);
        }
      }
    }

    return merged;
  }

  /**
   * Handle partial failures gracefully.
   *
   * When some tools fail, complete the available portions
   * using successful tool results.
   *
   * @param results - Array of tool results (some may have failed)
   * @returns Aggregated context from successful results
   *
   * Validates: Requirements 9.6
   */
  async handlePartialFailures(results: ToolResult[]): Promise<{
    context: AggregatedContext;
    failures: string[];
  }> {
    const successfulResults = results.filter((r) => r.success);
    const failures = results
      .filter((r) => !r.success)
      .map((r) => r.error || 'Unknown error');

    const context = await this.aggregateResults(successfulResults);

    return {
      context,
      failures,
    };
  }

  // Private helper methods

  private inferSurface(toolName: string): Surface {
    const lower = toolName.toLowerCase();
    if (lower.includes('email') || lower.includes('gmail')) return Surface.GMAIL;
    if (lower.includes('x_') || lower.includes('twitter')) return Surface.X;
    if (lower.includes('telegram')) return Surface.TELEGRAM;
    if (lower.includes('wallet') || lower.includes('token')) return Surface.WALLET;
    return Surface.WEB;
  }

  private extractSourcesFromData(items: any[], surface: Surface): Source[] {
    const sources: Source[] = [];

    for (const item of items) {
      const source = this.createSource(item, surface);
      if (source) {
        sources.push(source);
      }
    }

    return sources;
  }

  private createSource(item: any, surface: Surface): Source | null {
    // Extract identifier based on surface type
    let identifier = '';
    let preview = '';
    let timestamp = new Date();

    switch (surface) {
      case Surface.GMAIL:
        identifier = item.id || item.threadId || '';
        preview = item.subject || item.snippet || '';
        timestamp = item.date ? new Date(item.date) : timestamp;
        break;

      case Surface.X:
        identifier = item.id || '';
        preview = item.text || '';
        timestamp = item.timestamp ? new Date(item.timestamp) : timestamp;
        break;

      case Surface.TELEGRAM:
        identifier = item.id || '';
        preview = item.text || '';
        timestamp = item.timestamp ? new Date(item.timestamp) : timestamp;
        break;

      case Surface.WALLET:
        identifier = item.signature || item.mint || item.address || '';
        preview = item.description || item.symbol || '';
        timestamp = item.timestamp ? new Date(item.timestamp) : timestamp;
        break;

      case Surface.WEB:
        identifier = item.url || '';
        preview = item.title || item.snippet || '';
        timestamp = item.publishedDate ? new Date(item.publishedDate) : timestamp;
        break;
    }

    if (!identifier) {
      return null;
    }

    return {
      surface,
      identifier,
      timestamp,
      preview: preview.substring(0, 100), // Limit preview length
    };
  }

  private detectConflicts(surfaces: SurfaceData[]): boolean {
    // Simple conflict detection: check if same information appears in multiple surfaces
    // This is a placeholder - real implementation would use more sophisticated matching
    return surfaces.length > 1;
  }

  private combineText(surfaces: SurfaceData[]): string {
    let combined = '';

    for (const surfaceData of surfaces) {
      const text = this.extractText(surfaceData.data);
      if (text) {
        combined += text + '\n\n';
      }
    }

    return combined.trim();
  }

  private extractText(data: any): string {
    if (typeof data === 'string') {
      return data;
    }

    if (Array.isArray(data)) {
      return data.map((item) => this.extractText(item)).join('\n');
    }

    if (typeof data === 'object' && data !== null) {
      // Extract text from common fields
      const textFields = ['text', 'body', 'content', 'description', 'snippet'];
      for (const field of textFields) {
        if (data[field]) {
          return String(data[field]);
        }
      }

      // Fallback: stringify object
      return JSON.stringify(data);
    }

    return '';
  }

  private formatSurfaceData(surfaceData: SurfaceData): string {
    const items = Array.isArray(surfaceData.data)
      ? surfaceData.data
      : [surfaceData.data];

    let formatted = '';
    for (let i = 0; i < Math.min(items.length, 5); i++) {
      const item = items[i];
      formatted += `  - ${this.formatItem(item, surfaceData.surface)}\n`;
    }

    if (items.length > 5) {
      formatted += `  ... and ${items.length - 5} more items\n`;
    }

    return formatted;
  }

  private formatItem(item: any, surface: Surface): string {
    switch (surface) {
      case Surface.GMAIL:
        return `${item.subject || 'No subject'} from ${item.from || 'unknown'}`;

      case Surface.X:
        return `@${item.authorUsername || 'unknown'}: ${item.text?.substring(0, 50) || ''}`;

      case Surface.TELEGRAM:
        return `@${item.fromUsername || 'unknown'}: ${item.text?.substring(0, 50) || ''}`;

      case Surface.WALLET:
        if (item.symbol) {
          return `${item.symbol}: ${item.balance || 0} (${item.valueUsd || 0} USD)`;
        }
        return `Transaction: ${item.description || item.type || 'unknown'}`;

      case Surface.WEB:
        return `${item.title || 'No title'} (${item.url || 'no URL'})`;

      default:
        return JSON.stringify(item).substring(0, 100);
    }
  }

  private createItemKey(item: any, surface: Surface): string {
    // Create unique key for deduplication
    const id = item.id || item.signature || item.address || '';
    return `${surface}:${id}`;
  }
}

// Export singleton instance
export const contextAggregator = new ContextAggregator();
