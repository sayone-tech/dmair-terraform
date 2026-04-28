function handler(event) {
    var request = event.request;
    var headers = request.headers;

    // Basic Auth credentials (base64 encoded)
    var expectedAuth = "Basic ${basic_auth_credentials}";

    // Check if Authorization header exists and matches expected credentials
    if (!headers.authorization || headers.authorization.value !== expectedAuth) {
        return {
            statusCode: 401,
            statusDescription: "Unauthorized",
            headers: {
                "www-authenticate": { value: 'Basic realm="Restricted Area"' }
            }
        };
    }

    // Authorization successful, proceed with URL rewriting

    // Step 3: Append index.html for clean URLs
    // Exclude /email-sig and /static paths from rewriting
    var uri = request.uri;
    if (!uri.startsWith("/email-sig") && !uri.startsWith("/static") && !uri.includes('.') && !uri.endsWith('/index.html')) {
        if (uri.endsWith('/')) {
            request.uri += 'index.html';
        } else {
            request.uri += '/index.html';
        }
    }

    return request;
}

