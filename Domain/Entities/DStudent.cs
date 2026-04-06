namespace SRJBackend.Domain.Entities;

public class DStudent
{
    public int Id { get; private set; }
    public string? StudentCode { get; private set; }
    public string FullName { get; private set; }
    public DateOnly BirthDate { get; private set; }
    public string? Gender { get; private set; }
    public string? DocumentType { get; private set; }
    public string IdDocumentNumber { get; private set; }
    public string? Email { get; private set; }
    public string? CellPhone { get; private set; }
    public bool HasDisability { get; private set; }

    public DStudent(
        int id,
        string? studentCode,
        string fullName,
        DateOnly birthDate,
        string? gender,
        string? documentType,
        string idDocumentNumber,
        string? email,
        string? cellPhone,
        bool hasDisability)
    {
        Id = id;
        StudentCode = studentCode;
        FullName = fullName;
        BirthDate = birthDate;
        Gender = gender;
        DocumentType = documentType;
        IdDocumentNumber = idDocumentNumber;
        Email = email;
        CellPhone = cellPhone;
        HasDisability = hasDisability;
    }
}
