namespace SRJBackend.Domain.Entities;

public class DStudent : DEducationalPerson
{
    public bool HasElectronicDevices { get; private set; }
    public bool HasInternetAccess { get; private set; }
    public DLocation BirthLocation { get; private set; }
    public DLocation AddressLocation { get; private set; }
    public bool HasDisability { get; private set; }
    public short? Siblings { get; private set; }
    public int? ChildbirthTypeId { get; private set; }
    public List<DFamiliar> Familiars { get; private set; }
    public bool HasEligibleYears { get; set; }

    public DStudent(
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
        List<int>? secondLanguageIds,
        bool hasElectronicDevices,
        bool hasInternetAccess,
        DLocation birthLocation,
        DLocation addressLocation,
        bool hasDisability,
        short? siblings,
        int? childbirthTypeId,
        List<DFamiliar> familiars)
        : base(id, names, paternalLastname, maternalLastname, genderId, birthDate,
               documentTypeId, idDocumentNumber, address, addressUbigeoId,
               religionId, civilStateId, email, landlinePhone, cellPhone,
               nativeLanguageId, ethnicSelfIdentificationId, secondLanguageIds)
    {
        HasElectronicDevices = hasElectronicDevices;
        HasInternetAccess = hasInternetAccess;
        BirthLocation = birthLocation;
        AddressLocation = addressLocation;
        HasDisability = hasDisability;
        Siblings = siblings;
        ChildbirthTypeId = childbirthTypeId;
        Familiars = familiars;
    }
}