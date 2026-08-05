// skillsphone-cdn-ab-req-fn  (viewer-request, runtime: cloudfront-js-2.0)
//
// 동작 방식
// 1) Request Cookie 에 x-sp-ab 가 존재하면, 그 값(a or b)에 해당하는
//    KeyValueStore 의 version_a / version_b 경로로 Request URI 를 재조성한다.
// 2) x-sp-ab 가 없으면, KeyValueStore 의 weight 값을 읽어 0~1 무작위 값(t)과
//    비교한다. t < weight 이면 b, 아니면 a 를 할당한다.
// 3) 할당된 버전 경로로 Request URI 를 재조성하고, 다음 단계(viewer-response)에
//    전달하기 위해 요청 헤더 x-sp-ab-assigned 를 할당된 버전(a or b)으로 설정한다.
//
// NOTE 1: AWS 문서상 kvs.get() 은 키가 없거나 KVS 미동기화 시 에러를 던지므로
//         반드시 try/catch 로 감싸 함수가 절대 throw 하지 않도록 한다.
// NOTE 2: CloudFront Functions 엔진은 "함수 인자 자리의 await"(예:
//         parseFloat(await kvs.get(...)))를 지원하지 않는다. 따라서 await 결과는
//         반드시 변수에 먼저 받은 뒤 사용한다.
import cf from 'cloudfront';

// 함수에 연결된 KeyValueStore 핸들
var kvs = cf.kvs();

// KVS 읽기 실패(전파 지연 등) 시 사용할 기본값
var DEFAULT_WEIGHT = 0.3;
var DEFAULT_PATH = { a: '/version-a/index.html', b: '/version-b/index.html' };

async function getPath(version) {
    var key = version === 'b' ? 'version_b' : 'version_a';
    try {
        var p = await kvs.get(key);
        return p;
    } catch (e) {
        return DEFAULT_PATH[version];
    }
}

async function handler(event) {
    var request = event.request;
    var cookies = request.cookies;

    // 1) 기존 방문자 : 쿠키에 할당 버전이 존재
    if (cookies['x-sp-ab'] && cookies['x-sp-ab'].value) {
        var stickyVer = cookies['x-sp-ab'].value === 'b' ? 'b' : 'a';
        var stickyUri = await getPath(stickyVer);
        request.uri = stickyUri;
        return request;
    }

    // 2) 신규 방문자 : weight 기준 무작위 할당
    var weight = DEFAULT_WEIGHT;
    try {
        var w = await kvs.get('weight');
        weight = parseFloat(w);
    } catch (e) {
        weight = DEFAULT_WEIGHT;
    }
    var assigned = Math.random() < weight ? 'b' : 'a';

    // 3) 할당 버전 경로로 URI 재조성 + 다음 단계 전달용 헤더 설정
    var newUri = await getPath(assigned);
    request.uri = newUri;
    request.headers['x-sp-ab-assigned'] = { value: assigned };

    return request;
}
