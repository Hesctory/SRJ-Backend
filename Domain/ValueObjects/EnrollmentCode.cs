namespace SRJBackend.Domain.ValueObjects;

public record EnrollmentCode
{
    public string Code { get; }
    public int CodeNumber { get; }

    public EnrollmentCode(string code, int codeNumber)
    {
        if (string.IsNullOrWhiteSpace(code))
            throw new ArgumentException("El código de matrícula no puede estar vacío.", nameof(code));
        if (codeNumber <= 0)
            throw new ArgumentException("El número de código debe ser mayor a cero.", nameof(codeNumber));

        Code = code;
        CodeNumber = codeNumber;
    }

    public static EnrollmentCode Generate(int schoolYear, int maxCodeNumber)
    {
        var next = maxCodeNumber + 1;
        return new EnrollmentCode($"{schoolYear}-{next:D6}", next);
    }
}
