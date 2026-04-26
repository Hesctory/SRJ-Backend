namespace SRJBackend.Domain.Entities;

public class DFamiliar : DEducationalPerson
{
    public int? LevelOfEducationId { get; }
    public string? Occupation { get; }
    public string? WorkCenter { get; }
    public DLocation? AddressLocation { get; }
    public bool Lives { get; }
    public bool LivesWithStudent { get; }
    public int RelationshipId { get; }
    public bool IsGuardian { get; }

    public DFamiliar(
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
        int? levelOfEducationId,
        string? occupation,
        string? workCenter,
        DLocation? addressLocation,
        bool lives,
        bool livesWithStudent,
        int relationshipId,
        bool isGuardian)
        : base(id, names, paternalLastname, maternalLastname, genderId, birthDate,
               documentTypeId, idDocumentNumber, address, addressUbigeoId,
               religionId, civilStateId, email, landlinePhone, cellPhone,
               nativeLanguageId, ethnicSelfIdentificationId, secondLanguageIds)
    {
        LevelOfEducationId = levelOfEducationId;
        Occupation = occupation;
        WorkCenter = workCenter;
        AddressLocation = addressLocation;
        Lives = lives;
        LivesWithStudent = livesWithStudent;
        RelationshipId = relationshipId;
        IsGuardian = isGuardian;
    }
}
