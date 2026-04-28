function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Append index.html for clean URLs
    // Exclude /email-sig and /static paths from rewriting
    if (!uri.startsWith("/email-sig") && !uri.startsWith("/static") && !uri.includes('.') && !uri.endsWith('/index.html')) {
        if (uri.endsWith('/')) {
            request.uri += 'index.html';
        } else {
            request.uri += '/index.html';
        }
    }

    return request;
}
