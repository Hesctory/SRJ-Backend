using System.Text.RegularExpressions;

namespace SRJBackend.Domain.ValueObjects;

public partial record ContactInfo
{
    public string? Email { get; }
    public string? LandlinePhone { get; }
    public string? CellPhone { get; }

    public ContactInfo(string? email, string? landlinePhone, string? cellPhone)
    {
        if (email != null && !EmailRegex().IsMatch(email))
            throw new ArgumentException("El correo electrónico no es válido.", nameof(email));

        Email = email;
        LandlinePhone = landlinePhone;
        CellPhone = cellPhone;
    }

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.IgnoreCase)]
    private static partial Regex EmailRegex();
}
