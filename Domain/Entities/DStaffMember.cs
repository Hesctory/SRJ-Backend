using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Domain.Entities;

public class DStaffMember : DPerson
{
    public StaffProfile Profile { get; private set; }
    public bool IsActive { get; private set; }
    public bool IsArchived { get; private set; }

    public static DStaffMember Create(
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
        StaffProfile profile)
    {
        DPerson.Create(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);
        return new DStaffMember(id, name, genderId, birthDate, document, address, addressUbigeoId,
                                religionId, civilStateId, contact, profile, isActive: true, isArchived: false);
    }

    internal static DStaffMember Reconstitute(
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
        StaffProfile profile,
        bool isActive,
        bool isArchived)
        => new DStaffMember(id, name, genderId, birthDate, document, address, addressUbigeoId,
                            religionId, civilStateId, contact, profile, isActive, isArchived);

    public void Update(
        PersonalName name,
        int genderId,
        DateOnly birthDate,
        IdentityDocument document,
        string address,
        int addressUbigeoId,
        int? religionId,
        int? civilStateId,
        ContactInfo contact,
        StaffProfile profile)
    {
        DPerson.Create(0, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact);
        Profile = profile;
    }

    public void Archive() => IsArchived = true;
    public void Unarchive() => IsArchived = false;

    private DStaffMember(
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
        StaffProfile profile,
        bool isActive,
        bool isArchived)
        : base(id, name, genderId, birthDate, document, address, addressUbigeoId, religionId, civilStateId, contact)
    {
        Profile = profile;
        IsActive = isActive;
        IsArchived = isArchived;
    }
}
