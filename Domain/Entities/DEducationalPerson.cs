using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DEducationalPerson : DPerson
{
    public int NativeLanguageId { get; private set; }
    public int? EthnicSelfIdentificationId { get; private set; }
    public List<int>? SecondLanguageIds { get; private set; }

    public static DEducationalPerson Create(
        int id,
        PersonalName name,
        int genderId,
        DateOnly birthDate,
        IdentityDocument document,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        ContactInfo contact,
        int nativeLanguageId,
        int? ethnicSelfIdentificationId,
        List<int>? secondLanguageIds)
    {
        DPerson.Create(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);

        if (nativeLanguageId <= 0) throw new ArgumentException("Native language is required.", nameof(nativeLanguageId));

        return new DEducationalPerson(id, name, genderId, birthDate, document, address, addressUbigeoId,
                                      religionId, civilStateId, contact, nativeLanguageId,
                                      ethnicSelfIdentificationId, secondLanguageIds);
    }

    protected DEducationalPerson(
        int id,
        PersonalName name,
        int genderId,
        DateOnly birthDate,
        IdentityDocument document,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        ContactInfo contact,
        int nativeLanguageId,
        int? ethnicSelfIdentificationId,
        List<int>? secondLanguageIds)
        : base(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact)
    {
        NativeLanguageId = nativeLanguageId;
        EthnicSelfIdentificationId = ethnicSelfIdentificationId;
        SecondLanguageIds = secondLanguageIds;
    }
}
