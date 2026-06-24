namespace SRJBackend.Domain.Constants;

/// <summary>
/// Charge type codes for enrollment debts (mirrors the <c>charge_type.code</c> values
/// in the database) plus helpers for building debt descriptions, matching the wording
/// produced by <c>database/backfill_enrollment_debts.sql</c>.
/// </summary>
public static class ChargeTypeCodes
{
    public const string Admission = "ADMISSION";   // Cuota de Ingreso
    public const string Enrollment = "ENROLLMENT";  // Matrícula
    public const string Tuition = "TUITION";        // Pensión (monthly)

    private static readonly Dictionary<short, string> MonthNames = new()
    {
        [3] = "Marzo",
        [4] = "Abril",
        [5] = "Mayo",
        [6] = "Junio",
        [7] = "Julio",
        [8] = "Agosto",
        [9] = "Septiembre",
        [10] = "Octubre",
        [11] = "Noviembre",
        [12] = "Diciembre",
    };

    public static string MonthName(short month) =>
        MonthNames.TryGetValue(month, out var name) ? name : month.ToString();

    public static string AdmissionDescription(int year) => $"Cuota de Ingreso {year}";

    public static string EnrollmentDescription(int year) => $"Matrícula {year}";

    public static string TuitionDescription(short month, int year) =>
        $"Pensión {MonthName(month)} - {year}";
}
