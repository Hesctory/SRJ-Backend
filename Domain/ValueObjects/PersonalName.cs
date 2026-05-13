namespace SRJBackend.Domain.ValueObjects;

public record PersonalName
{
    public string Names { get; }
    public string PaternalLastname { get; }
    public string MaternalLastname { get; }
    public string Full => $"{Names} {PaternalLastname} {MaternalLastname}".Trim();

    public PersonalName(string names, string paternalLastname, string maternalLastname)
    {
        if (string.IsNullOrWhiteSpace(names))
            throw new ArgumentException("Names cannot be empty.", nameof(names));
        if (string.IsNullOrWhiteSpace(paternalLastname))
            throw new ArgumentException("Paternal lastname cannot be empty.", nameof(paternalLastname));
        if (string.IsNullOrWhiteSpace(maternalLastname))
            throw new ArgumentException("Maternal lastname cannot be empty.", nameof(maternalLastname));

        Names = names;
        PaternalLastname = paternalLastname;
        MaternalLastname = maternalLastname;
    }
}
