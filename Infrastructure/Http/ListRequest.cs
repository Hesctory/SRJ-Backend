using System.Text.Json;

namespace SRJBackend.Infrastructure.Http;

/// <summary>
/// Parses the React-Admin style <c>range</c> and <c>filter</c> query params shared by every list
/// endpoint. Malformed input throws <see cref="ArgumentException"/>, which GlobalExceptionHandler
/// maps to 400.
/// </summary>
public static class ListRequest
{
    private static readonly JsonSerializerOptions FilterOptions = new(JsonSerializerDefaults.Web);

    /// <summary>"[start,end]" → (skip, take). A null range means the whole list (0, int.MaxValue).</summary>
    public static (int Skip, int Take) ParseRange(string? range)
    {
        if (range is null) return (0, int.MaxValue);

        int[]? bounds;
        try { bounds = JsonSerializer.Deserialize<int[]>(range); }
        catch (JsonException) { throw new ArgumentException("Invalid range"); }

        if (bounds is not { Length: 2 }) throw new ArgumentException("Invalid range");

        var skip = bounds[0];
        return (skip, bounds[1] - skip + 1);
    }

    /// <summary>"{...}" → a typed filter record (camelCase keys). A null filter means null.</summary>
    public static TFilter? ParseFilter<TFilter>(string? filter) where TFilter : class
    {
        if (filter is null) return null;
        try { return JsonSerializer.Deserialize<TFilter>(filter, FilterOptions); }
        catch (JsonException) { throw new ArgumentException("Invalid filter"); }
    }

    /// <summary>"{...}" → a raw dictionary, for query layers that interpret the JSON directly.</summary>
    public static Dictionary<string, JsonElement>? ParseFilterDictionary(string? filter)
    {
        if (filter is null) return null;
        try { return JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(filter); }
        catch (JsonException) { throw new ArgumentException("Invalid filter"); }
    }
}
