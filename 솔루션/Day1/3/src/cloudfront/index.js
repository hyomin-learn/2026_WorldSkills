function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri.startsWith('/booking')) {
        request.uri = uri.replace('/booking', '/v1/book');
    }

    return request;
}