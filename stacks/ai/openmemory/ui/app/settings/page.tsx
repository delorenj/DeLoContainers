"use client";

import { useState, useEffect } from 'react';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";
import { Loader2, Save, RotateCcw } from "lucide-react";

interface Config {
  openmemory: {
    custom_instructions: string | null;
  };
  mem0: {
    llm: {
      provider: string;
      config: {
        model: string;
        temperature: number;
        max_tokens: number;
        api_key: string;
        ollama_base_url?: string;
      };
    };
    embedder: {
      provider: string;
      config: {
        model: string;
        api_key: string;
        ollama_base_url?: string;
      };
    };
  };
}

export default function SettingsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const { toast } = useToast();

  const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8765";

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${API_URL}/api/v1/config/`);
      if (response.ok) {
        const data = await response.json();
        setConfig(data);
      } else {
        throw new Error('Failed to fetch configuration');
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load configuration",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const saveConfig = async () => {
    if (!config) return;

    try {
      setSaving(true);
      const response = await fetch(`${API_URL}/api/v1/config/`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(config),
      });

      if (response.ok) {
        toast({
          title: "Success",
          description: "Configuration saved successfully",
        });
      } else {
        throw new Error('Failed to save configuration');
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to save configuration",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  const resetConfig = async () => {
    try {
      setSaving(true);
      const response = await fetch(`${API_URL}/api/v1/config/reset`, {
        method: 'POST',
      });

      if (response.ok) {
        await fetchConfig();
        toast({
          title: "Success",
          description: "Configuration reset to defaults",
        });
      } else {
        throw new Error('Failed to reset configuration');
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to reset configuration",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  const updateConfig = (path: string[], value: any) => {
    if (!config) return;

    const newConfig = { ...config };
    let current: any = newConfig;
    
    for (let i = 0; i < path.length - 1; i++) {
      current = current[path[i]];
    }
    
    current[path[path.length - 1]] = value;
    setConfig(newConfig);
  };

  if (loading) {
    return (
      <div className="container mx-auto p-6">
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      </div>
    );
  }

  if (!config) {
    return (
      <div className="container mx-auto p-6">
        <div className="text-center">
          <p className="text-muted-foreground">Failed to load configuration</p>
          <Button onClick={fetchConfig} className="mt-4">
            Retry
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Settings</h1>
          <p className="text-muted-foreground">Configure your OpenMemory instance</p>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={resetConfig}
            variant="outline"
            disabled={saving}
          >
            <RotateCcw className="h-4 w-4 mr-2" />
            Reset
          </Button>
          <Button
            onClick={saveConfig}
            disabled={saving}
          >
            {saving ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-2" />
            )}
            Save Changes
          </Button>
        </div>
      </div>

      <div className="grid gap-6">
        {/* OpenMemory Settings */}
        <Card>
          <CardHeader>
            <CardTitle>OpenMemory Settings</CardTitle>
            <CardDescription>
              Configure general OpenMemory behavior
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="custom-instructions">Custom Instructions</Label>
              <Textarea
                id="custom-instructions"
                placeholder="Enter custom instructions for memory processing..."
                value={config.openmemory.custom_instructions || ''}
                onChange={(e) => updateConfig(['openmemory', 'custom_instructions'], e.target.value)}
                className="mt-2"
              />
            </div>
          </CardContent>
        </Card>

        {/* LLM Settings */}
        <Card>
          <CardHeader>
            <CardTitle>Language Model (LLM) Settings</CardTitle>
            <CardDescription>
              Configure the language model used for memory processing
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="llm-provider">Provider</Label>
                <Select
                  value={config.mem0.llm.provider}
                  onValueChange={(value) => updateConfig(['mem0', 'llm', 'provider'], value)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ollama">Ollama</SelectItem>
                    <SelectItem value="openai">OpenAI</SelectItem>
                    <SelectItem value="anthropic">Anthropic</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label htmlFor="llm-model">Model</Label>
                <Input
                  id="llm-model"
                  value={config.mem0.llm.config.model}
                  onChange={(e) => updateConfig(['mem0', 'llm', 'config', 'model'], e.target.value)}
                />
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="llm-temperature">Temperature</Label>
                <Input
                  id="llm-temperature"
                  type="number"
                  min="0"
                  max="2"
                  step="0.1"
                  value={config.mem0.llm.config.temperature}
                  onChange={(e) => updateConfig(['mem0', 'llm', 'config', 'temperature'], parseFloat(e.target.value))}
                />
              </div>
              <div>
                <Label htmlFor="llm-max-tokens">Max Tokens</Label>
                <Input
                  id="llm-max-tokens"
                  type="number"
                  value={config.mem0.llm.config.max_tokens}
                  onChange={(e) => updateConfig(['mem0', 'llm', 'config', 'max_tokens'], parseInt(e.target.value))}
                />
              </div>
            </div>

            {config.mem0.llm.provider === 'ollama' && (
              <div>
                <Label htmlFor="llm-ollama-url">Ollama Base URL</Label>
                <Input
                  id="llm-ollama-url"
                  value={config.mem0.llm.config.ollama_base_url || ''}
                  onChange={(e) => updateConfig(['mem0', 'llm', 'config', 'ollama_base_url'], e.target.value)}
                />
              </div>
            )}
          </CardContent>
        </Card>

        {/* Embedder Settings */}
        <Card>
          <CardHeader>
            <CardTitle>Embedder Settings</CardTitle>
            <CardDescription>
              Configure the embedding model used for memory storage
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="embedder-provider">Provider</Label>
                <Select
                  value={config.mem0.embedder.provider}
                  onValueChange={(value) => updateConfig(['mem0', 'embedder', 'provider'], value)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ollama">Ollama</SelectItem>
                    <SelectItem value="openai">OpenAI</SelectItem>
                    <SelectItem value="huggingface">Hugging Face</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label htmlFor="embedder-model">Model</Label>
                <Input
                  id="embedder-model"
                  value={config.mem0.embedder.config.model}
                  onChange={(e) => updateConfig(['mem0', 'embedder', 'config', 'model'], e.target.value)}
                />
              </div>
            </div>

            {config.mem0.embedder.provider === 'ollama' && (
              <div>
                <Label htmlFor="embedder-ollama-url">Ollama Base URL</Label>
                <Input
                  id="embedder-ollama-url"
                  value={config.mem0.embedder.config.ollama_base_url || ''}
                  onChange={(e) => updateConfig(['mem0', 'embedder', 'config', 'ollama_base_url'], e.target.value)}
                />
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
