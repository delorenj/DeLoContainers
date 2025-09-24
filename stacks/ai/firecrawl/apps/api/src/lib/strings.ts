import { isSelfHosted } from "./deployment";

export const BLOCKLISTED_URL_MESSAGE = isSelfHosted()
  ? "This website is no longer supported. Please check your server configuration and logs for more details."
  : "This website is no longer supported, please reach out to help@firecrawl.com for more info on how to activate it on your account.";
