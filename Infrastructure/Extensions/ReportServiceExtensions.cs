using PdfSharp.Fonts;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Reports;

namespace SRJBackend.Infrastructure.Extensions;

public static class ReportServiceExtensions
{
    public static IServiceCollection AddReportServices(this IServiceCollection services)
    {
        // PdfSharp needs a font resolver on non-Windows hosts (no Microsoft fonts).
        // Set once at startup, before any PDF is rendered.
        GlobalFontSettings.FontResolver ??= new ReportFontResolver();

        // Renderers are stateless → singletons.
        services.AddSingleton<TablePdfRenderer>();
        services.AddSingleton<TableExcelRenderer>();
        services.AddSingleton<RegistrationCardPdfRenderer>();
        services.AddSingleton<RegistrationCardExcelRenderer>();

        // The exporter depends on the (scoped) query layer.
        services.AddScoped<IStudentReportExporter, StudentReportExporter>();
        return services;
    }
}
