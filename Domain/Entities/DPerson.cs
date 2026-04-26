namespace SRJBackend.Domain.Entities;

public class DPerson
{
    public int Id { get; private set; }
    public string Names { get; private set; }
    public string PaternalLastname { get; private set; }
    public string MaternalLastname { get; private set; }
    public string FullName => $"{Names} {PaternalLastname} {MaternalLastname}".Trim();
    public int GenderId { get; private set; }
    public DateOnly BirthDate { get; private set; }
    public int DocumentTypeId { get; private set; }
    public string IdDocumentNumber { get; private set; }
    public string Address { get; private set; }
    public int AddressUbigeoId { get; private set; }
    public int? ReligionId { get; private set; }
    public int? CivilStateId { get; private set; }
    public string? Email { get; private set; }
    public string? LandlinePhone { get; private set; }
    public string? CellPhone { get; private set; }

    public static DPerson Create(
        int id,
        string names,
        string paternalLastname,
        string maternalLastname,
        int genderId,
        DateOnly birthDate,
        int documentTypeId,
        string idDocumentNumber,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        string? email,
        string? landlinePhone,
        string? cellPhone)
    {
        if (string.IsNullOrWhiteSpace(names)) throw new ArgumentException("Names cannot be empty.", nameof(names));
        if (string.IsNullOrWhiteSpace(paternalLastname)) throw new ArgumentException("Paternal lastname cannot be empty.", nameof(paternalLastname));
        if (string.IsNullOrWhiteSpace(maternalLastname)) throw new ArgumentException("Maternal lastname cannot be empty.", nameof(maternalLastname));
        if (string.IsNullOrWhiteSpace(idDocumentNumber)) throw new ArgumentException("Document number cannot be empty.", nameof(idDocumentNumber));
        if (string.IsNullOrWhiteSpace(address)) throw new ArgumentException("Address cannot be empty.", nameof(address));
        if (genderId <= 0) throw new ArgumentException("Gender is required.", nameof(genderId));
        if (documentTypeId <= 0) throw new ArgumentException("Document type is required.", nameof(documentTypeId));
        if (addressUbigeoId <= 0) throw new ArgumentException("Address location is required.", nameof(addressUbigeoId));
        if (birthDate == default) throw new ArgumentException("Birth date is required.", nameof(birthDate));

        return new DPerson(id, names, paternalLastname, maternalLastname, genderId, birthDate,
                           documentTypeId, idDocumentNumber, address, addressUbigeoId,
                           religionId, civilStateId, email, landlinePhone, cellPhone);
    }

    public DPerson(
        int id,
        string names,
        string paternalLastname,
        string maternalLastname,
        int genderId,
        DateOnly birthDate,
        int documentTypeId,
        string idDocumentNumber,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        string? email,
        string? landlinePhone,
        string? cellPhone)
    {
        Id = id;
        Names = names;
        PaternalLastname = paternalLastname;
        MaternalLastname = maternalLastname;
        GenderId = genderId;
        BirthDate = birthDate;
        DocumentTypeId = documentTypeId;
        IdDocumentNumber = idDocumentNumber;
        Address = address;
        AddressUbigeoId = addressUbigeoId;
        ReligionId = religionId;
        CivilStateId = civilStateId;
        Email = email;
        LandlinePhone = landlinePhone;
        CellPhone = cellPhone;
    }
}

/*
    Forced Data:
    string names,
    string paternalLastname,
    string maternalLastname,
    int genderId,
    DateOnly birthDate,
    int documentTypeId,
    string idDocumentNumber,
    string address,
    int addressUbigeoId,
    int? religionId,
    int? civilStateId
*/