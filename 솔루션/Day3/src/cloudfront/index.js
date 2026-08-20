function handler(event) {
    var request = event.request;
    var response = event.response;

    if (!response.headers) {
        response.headers = {};
    }

    var filename = request.uri.split("/").pop() || "download";

    filename = filename
        .replace(/"/g, "_")
        .replace(/\\/g, "_")
        .replace(/\r/g, "_")
        .replace(/\n/g, "_");

    response.headers["content-disposition"] = {
        value: 'attachment; filename="' + filename + '"'
    };

    return response;
}