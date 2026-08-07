// skillsphone-cdn-ab-res-fn  (viewer-response, runtime: cloudfront-js-2.0)
//
// 동작 방식
// - 요청 헤더 x-sp-ab-assigned 가 존재하는 경우에만, 응답에
//   x-sp-ab=<할당된 버전>; Path=/; Max-Age=86400 쿠키를 추가한다.
//   (재접속 시에도 동일 버전이 유지되도록 쿠키를 심는다.)
//
// NOTE: CloudFront Functions(viewer-response)는 response.headers 에
//       'set-cookie' 를 직접 넣는 것을 금지(MisplacedCookies)한다.
//       반드시 response.cookies 객체를 사용해야 하며, CloudFront 가 이를
//       Set-Cookie: x-sp-ab=<v>; Path=/; Max-Age=86400 으로 직렬화한다.
function handler(event) {
    var request = event.request;
    var response = event.response;
    var reqHeaders = request.headers;

    if (reqHeaders['x-sp-ab-assigned'] && reqHeaders['x-sp-ab-assigned'].value) {
        var assigned = reqHeaders['x-sp-ab-assigned'].value;

        if (!response.cookies) {
            response.cookies = {};
        }
        response.cookies['x-sp-ab'] = {
            value: assigned,
            attributes: 'Path=/; Max-Age=86400'
        };
    }

    return response;
}
