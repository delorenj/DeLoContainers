import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

export const callPublisher = async (data: any) => {
  try {
    console.log('Entering pubsub');
    // Create SNS service object with credentials from environment variables

    const client = new SNSClient({
      region: process.env.AWS_REGION || 'us-east-1',
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      },
    });

    // The topic ARN
    const topicArn = process.env.AWS_SNS_TOPIC || 'arn:aws:sns:us-east-1:757431874381:firecrawl';

    // The message to publish
    const message = JSON.stringify(data, null, 2);

    // Parameters for the publish method
    const params = {
      Message: message,
      TopicArn: topicArn,
    };

    // Publish the message
    const result = await client.send(new PublishCommand(params));
    console.log('Message published:', result.MessageId);

  } catch (error) {
    console.error(`Error sending publisher: ...`, error.message);
  }
};
