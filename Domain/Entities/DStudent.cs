using SRJBackend.Domain.Exceptions;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DStudent : DPerson
{
    private const string GuardianRequired = "El estudiante debe tener al menos un familiar designado como tutor.";

    public EducationalDemographics Demographics { get; private set; }
    public StudentProfile Profile { get; private set; }
    public DLocation BirthLocation { get; private set; }
    public DLocation AddressLocation { get; private set; }
    public List<DFamiliar> Familiars { get; private set; }

    public bool HasGuardian => Familiars.Any(f => f.IsGuardian);
    public bool IsMinor => BirthDate.AddYears(18) > DateOnly.FromDateTime(DateTime.Today);

    public static DStudent Create(
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
        StudentProfile profile,
        DLocation birthLocation,
        DLocation addressLocation,
        List<DFamiliar> familiars)
    {
        DPerson.Create(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);

        if (birthLocation.DistrictId <= 0)
            throw new ArgumentException("Birth location (district) is required.", nameof(birthLocation));

        if (!familiars.Any(f => f.IsGuardian))
            throw new DomainException(GuardianRequired);

        return new DStudent(id, name, genderId, birthDate, document, address, addressUbigeoId,
                            religionId, civilStateId, contact, demographics, profile,
                            birthLocation, addressLocation, familiars);
    }

    internal static DStudent Reconstitute(
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
        StudentProfile profile,
        DLocation birthLocation,
        DLocation addressLocation,
        List<DFamiliar> familiars)
        => new DStudent(id, name, genderId, birthDate, document, address, addressUbigeoId,
                        religionId, civilStateId, contact, demographics, profile,
                        birthLocation, addressLocation, familiars);

    public void UpdateFamiliars(List<DFamiliar> newFamiliars)
    {
        if (!newFamiliars.Any(f => f.IsGuardian))
            throw new DomainException(GuardianRequired);
        Familiars = newFamiliars;
    }

    private DStudent(
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
        StudentProfile profile,
        DLocation birthLocation,
        DLocation addressLocation,
        List<DFamiliar> familiars)
        : base(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact)
    {
        Demographics = demographics;
        Profile = profile;
        BirthLocation = birthLocation;
        AddressLocation = addressLocation;
        Familiars = familiars;
    }
}
