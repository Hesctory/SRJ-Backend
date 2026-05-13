using SRJBackend.Domain.Exceptions;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DFamiliar : DPerson
{
    public EducationalDemographics Demographics { get; }
    public int? LevelOfEducationId { get; }
    public string? Occupation { get; }
    public string? WorkCenter { get; }
    public DLocation? AddressLocation { get; }
    public bool Lives { get; }
    public bool LivesWithStudent { get; }
    public int RelationshipId { get; }
    public bool IsGuardian { get; }

    public static DFamiliar Create(
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
        EducationalDemographics demographics,
        int? levelOfEducationId,
        string? occupation,
        string? workCenter,
        DLocation? addressLocation,
        bool lives,
        bool livesWithStudent,
        int relationshipId,
        bool isGuardian)
    {
        DPerson.Create(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);

        if (relationshipId <= 0)
            throw new ArgumentException("Relationship type is required.", nameof(relationshipId));

        if (livesWithStudent && !lives)
            throw new DomainException("Un familiar no puede convivir con el estudiante si no está vivo.");

        return new DFamiliar(id, name, genderId, birthDate, document, address, addressUbigeoId,
                             religionId, civilStateId, contact, demographics, levelOfEducationId,
                             occupation, workCenter, addressLocation, lives, livesWithStudent,
                             relationshipId, isGuardian);
    }

    internal static DFamiliar Reconstitute(
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
        EducationalDemographics demographics,
        int? levelOfEducationId,
        string? occupation,
        string? workCenter,
        DLocation? addressLocation,
        bool lives,
        bool livesWithStudent,
        int relationshipId,
        bool isGuardian)
        => new DFamiliar(id, name, genderId, birthDate, document, address, addressUbigeoId,
                         religionId, civilStateId, contact, demographics, levelOfEducationId,
                         occupation, workCenter, addressLocation, lives, livesWithStudent,
                         relationshipId, isGuardian);

    private DFamiliar(
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
        EducationalDemographics demographics,
        int? levelOfEducationId,
        string? occupation,
        string? workCenter,
        DLocation? addressLocation,
        bool lives,
        bool livesWithStudent,
        int relationshipId,
        bool isGuardian)
        : base(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact)
    {
        Demographics = demographics;
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
