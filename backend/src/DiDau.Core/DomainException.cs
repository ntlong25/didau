namespace DiDau.Core;

public sealed class DomainException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
    public static DomainException CityNotSupported() => new("CITY_NOT_SUPPORTED", "Chưa hỗ trợ khu vực này. Hãy chọn Hà Nội, TP. Hồ Chí Minh, Đà Lạt, Nha Trang hoặc Đà Nẵng.");
    public static DomainException InsufficientData() => new("INSUFFICIENT_DATA", "Chưa đủ dữ liệu để tạo tour. Hãy chọn khu vực khác hoặc tăng thời lượng.");
    public static DomainException Validation(string message) => new("VALIDATION_ERROR", message);
}
