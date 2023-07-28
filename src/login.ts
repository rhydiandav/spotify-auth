import { missingEnvVarsErrorMessage } from "./constants";

exports.handler = async () => {
  try {
    const { CLIENT_ID, REDIRECT_URI, SCOPE } = process.env;

    if (!CLIENT_ID || !REDIRECT_URI || !SCOPE) {
      throw new Error(missingEnvVarsErrorMessage);
    }

    return {
      statusCode: 302,
      headers: {
        Location: `https://accounts.spotify.com/authorize?client_id=${CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}`,
      },
    };
  } catch (err) {
    if (err) {
      console.log(err);
      return {
        statusCode: 500,
        body: err instanceof Error ? err.message : err,
      };
    }
  }
};
