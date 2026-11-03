using System.Globalization;
using DiDau.Core.Places;

namespace DiDau.Core.Suggestions;

public static class ReasonBuilder
{
    public static string Build(Place p, bool? open)
    {
        var facts = new List<string>();
        if (!string.IsNullOrWhiteSpace(p.EditorialSummary)) facts.Add(p.EditorialSummary.TrimEnd('.'));
        if (p.Rating is not null) facts.Add($"đánh giá {p.Rating.Value.ToString("0.#", CultureInfo.GetCultureInfo("vi-VN"))}/5" + (p.UserRatingCount is not null ? $" từ {p.UserRatingCount} lượt" : ""));
        if (open == true) facts.Add("đang mở cửa");
        return facts.Count == 0 ? "Địa điểm phù hợp với nhu cầu tìm kiếm của bạn." : string.Join("; ", facts) + ".";
    }
}
