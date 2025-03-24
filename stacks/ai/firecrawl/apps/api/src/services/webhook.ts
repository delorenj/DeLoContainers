import { supabase_service } from "./supabase";

export const callWebhook = async (teamId: string, data: any) => {
  try {
    const selfHostedUrl = process.env.SELF_HOSTED_WEBHOOK_URL;
    let webhookUrl = selfHostedUrl;

    if (!selfHostedUrl) {
      const { data: webhooksData, error } = await supabase_service
        .from("webhooks")
        .select("url")
        .eq("team_id", teamId)
        .limit(1);

      if (error) {
        console.error(
          `Error fetching webhook URL for team ID: ${teamId}`,
          error.message
        );
        return null;
      }

      if (!webhooksData || webhooksData.length === 0) {
        return null;
      }

      webhookUrl = webhooksData[0].url;
    }

    let dataToSend = [];
    if (data.result.links && data.result.links.length !== 0) {
      for (let i = 0; i < data.result.links.length; i++) {
        dataToSend.push({
          content: data.result.links[i].content.content,
          markdown: data.result.links[i].content.markdown,
          metadata: data.result.links[i].content.metadata,
        });
      }
    }

    await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        success: data.success,
        data: dataToSend,
        error: data.error || undefined,
      }),
    });
  } catch (error) {
    console.error(
      `Error sending webhook for team ID: ${teamId}`,
      error.message
    );
  }
};
