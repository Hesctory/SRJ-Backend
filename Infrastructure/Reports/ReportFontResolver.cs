using System.Collections.Concurrent;
using PdfSharp.Fonts;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// PdfSharp font resolver for headless (non-Windows) hosts, which ship no Microsoft
/// fonts. Every requested family is mapped to Liberation Sans, which is metric-compatible
/// with Arial/Helvetica — the font the reports were originally designed against — so the
/// spacing matches. Requires the Liberation fonts to be installed (Debian/Ubuntu:
/// <c>fonts-liberation</c>; most Linux images already have them).
/// </summary>
public sealed class ReportFontResolver : IFontResolver
{
    private const string Regular = "LiberationSans-Regular";
    private const string Bold = "LiberationSans-Bold";
    private const string Italic = "LiberationSans-Italic";
    private const string BoldItalic = "LiberationSans-BoldItalic";

    private static readonly string[] FontDirs =
    {
        "/usr/share/fonts/truetype/liberation",
        "/usr/share/fonts/truetype/liberation2",
        "/usr/share/fonts/liberation",
        "/usr/share/fonts/TTF",
        "/Library/Fonts",
    };

    private static readonly ConcurrentDictionary<string, byte[]> Cache = new();

    public FontResolverInfo? ResolveTypeface(string familyName, bool isBold, bool isItalic)
    {
        var face = (isBold, isItalic) switch
        {
            (true, true) => BoldItalic,
            (true, false) => Bold,
            (false, true) => Italic,
            _ => Regular
        };
        return new FontResolverInfo(face);
    }

    public byte[]? GetFont(string faceName)
    {
        return Cache.GetOrAdd(faceName, static name =>
        {
            var fileName = name + ".ttf";
            foreach (var dir in FontDirs)
            {
                var path = Path.Combine(dir, fileName);
                if (File.Exists(path))
                    return File.ReadAllBytes(path);
            }
            throw new FileNotFoundException(
                $"Could not locate font '{fileName}'. Install the Liberation fonts (e.g. 'fonts-liberation').");
        });
    }
}
