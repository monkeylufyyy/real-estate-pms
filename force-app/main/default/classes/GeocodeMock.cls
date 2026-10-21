@IsTest
public class GeocodeMock implements HttpCalloutMock {
    public static Integer calls = 0;

    private Integer statusCode;
    private String body;

    public GeocodeMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public static GeocodeMock chennai() {
        return new GeocodeMock(200, '[{"lat":"13.0827","lon":"80.2707","display_name":"Chennai"}]');
    }

    public HttpResponse respond(HttpRequest request) {
        calls++;
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(body);
        return response;
    }
}
