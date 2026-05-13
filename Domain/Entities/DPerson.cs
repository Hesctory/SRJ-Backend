using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DPerson
{
    public int Id { get; private set; }
    public PersonalName Name { get; private set; }
    public int GenderId { get; private set; }
    public DateOnly BirthDate { get; private set; }
    public IdentityDocument Document { get; private set; }
    public string Address { get; private set; }
    public int AddressUbigeoId { get; private set; }
    public int? ReligionId { get; private set; }
    public int? CivilStateId { get; private set; }
    public ContactInfo Contact { get; private set; }

    public string FullName => Name.Full;

    public static DPerson Create(
        int id,
        PersonalName name,
        int genderId,
        DateOnly birthDate,
        IdentityDocument document,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        ContactInfo contact)
    {
        if (genderId <= 0) throw new ArgumentException("Gender is required.", nameof(genderId));
        if (birthDate == default) throw new ArgumentException("Birth date is required.", nameof(birthDate));
        if (string.IsNullOrWhiteSpace(address)) throw new ArgumentException("Address cannot be empty.", nameof(address));
        if (addressUbigeoId <= 0) throw new ArgumentException("Address location is required.", nameof(addressUbigeoId));

        return new DPerson(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);
    }

    protected DPerson(
        int id,
        PersonalName name,
        int genderId,
        DateOnly birthDate,
        IdentityDocument document,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        ContactInfo contact)
    {
        Id = id;
        Name = name;
        GenderId = genderId;
        BirthDate = birthDate;
        Document = document;
        Address = address;
        AddressUbigeoId = addressUbigeoId;
        ReligionId = religionId;
        CivilStateId = civilStateId;
        Contact = contact;
    }
}
