namespace SRJBackend.Infrastructure.Http;

/// <summary>
/// Writes the React-Admin <c>Content-Range</c> response header for list endpoints.
/// </summary>
public static class ContentRangeExtensions
{
    /// <summary>
    /// Emits "<paramref name="resource"/> skip-end/total" with a guarded end so an empty page
    /// yields "skip-skip" (e.g. "0-0/0") instead of an off-by-one "0--1/0".
    /// </summary>
    public static void SetContentRange<T>(
        this HttpResponse response, string resource, int skip, IReadOnlyCollection<T> items, int total)
    {
        var end = items.Count == 0 ? skip : skip + items.Count - 1;
        response.Headers.Append("Content-Range", $"{resource} {skip}-{end}/{total}");
    }

    /// <summary>Full-list convenience (skip 0, total == items.Count) for lookup endpoints.</summary>
    public static void SetContentRange<T>(this HttpResponse response, string resource, IReadOnlyCollection<T> items)
        => response.SetContentRange(resource, 0, items, items.Count);
}
