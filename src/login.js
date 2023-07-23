exports.handler = async () => {
  return {
    statusCode: 200,
    headers: "application/json",
    body: JSON.stringify({
      message: "Hello world!",
    }),
  };
};
