function handler(event) {
    var request = event.request;

    // book 애플리케이션은 내부적으로 POST /v1/book 에서만 응답한다(Reference02).
    // 외부(CloudFront/ALB)는 항상 /book 경로를 사용하므로, POST 요청만 /v1/book 으로 재작성한다.
    // GET(/book?concert_name=...) 은 Lambda 대상이며 경로를 사용하지 않으므로 그대로 둔다.
    if (request.method === 'POST' && request.uri === '/book') {
        request.uri = '/v1/book';
    }

    return request;
}
