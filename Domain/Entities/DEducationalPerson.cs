namespace SRJBackend.Domain.Entities;

public class DEducationalPerson : DPerson
{
    public int NativeLanguageId { get; private set; }
    public int? EthnicSelfIdentificationId { get; private set; }
    public List<int>? SecondLanguageIds { get; private set; }

    public static DEducationalPerson Create(
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
        string? cellPhone,
        int nativeLanguageId,
        int? ethnicSelfIdentificationId,
        List<int>? secondLanguageIds)
    {
        DPerson.Create(id, names, paternalLastname, maternalLastname, genderId, birthDate,
                       documentTypeId, idDocumentNumber, address, addressUbigeoId,
                       religionId, civilStateId, email, landlinePhone, cellPhone);

        if (nativeLanguageId <= 0) throw new ArgumentException("Native language is required.", nameof(nativeLanguageId));

        return new DEducationalPerson(id, names, paternalLastname, maternalLastname, genderId, birthDate,
                                      documentTypeId, idDocumentNumber, address, addressUbigeoId,
                                      religionId, civilStateId, email, landlinePhone, cellPhone,
                                      nativeLanguageId, ethnicSelfIdentificationId, secondLanguageIds);
    }

    public DEducationalPerson(
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
        string? cellPhone,
        int nativeLanguageId,
        int? ethnicSelfIdentificationId,
        List<int>? secondLanguageIds)
        : base(id, names, paternalLastname, maternalLastname, genderId, birthDate,
               documentTypeId, idDocumentNumber, address, addressUbigeoId,
               religionId, civilStateId, email, landlinePhone, cellPhone)
    {
        NativeLanguageId = nativeLanguageId;
        EthnicSelfIdentificationId = ethnicSelfIdentificationId;
        SecondLanguageIds = secondLanguageIds;
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
        int? civilStateId,
        int nativeLanguageId,
*/