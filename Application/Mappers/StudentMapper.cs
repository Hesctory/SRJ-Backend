using SRJBackend.Application.DTOs;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.Mappers;

public static class StudentMapper
{
    public static DStudent FromDTO(CreateStudentDTO dto, int id = 0)
    {
        var name = new PersonalName(dto.Names, dto.PaternalLastname, dto.MaternalLastname);
        var document = new IdentityDocument(dto.DocumentTypeId, dto.IdDocumentNumber);
        var contact = new ContactInfo(dto.Email, dto.LandlinePhone, dto.CellPhone);
        var demographics = new EducationalDemographics(dto.NativeLanguageId, dto.EthnicSelfIdentificationId, dto.SecondLanguageIds);
        var profile = new StudentProfile(dto.HasElectronicDevices, dto.HasInternetAccess, dto.HasDisability, dto.Siblings, dto.ChildbirthTypeId);
        var familiars = dto.Familiars.Select(FamiliarFromDTO).ToList();

        return DStudent.Create(
            id: id,
            name: name,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            document: document,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation!.DistrictId,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            contact: contact,
            demographics: demographics,
            profile: profile,
            birthLocation: new DLocation(dto.BirthLocation.DepartmentId, dto.BirthLocation.ProvinceId, dto.BirthLocation.DistrictId),
            addressLocation: new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId),
            familiars: familiars
        );
    }

    public static DStudent FromDTO(UpdateStudentDTO dto, int id = 0)
    {
        var name = new PersonalName(dto.Names, dto.PaternalLastname, dto.MaternalLastname);
        var document = new IdentityDocument(dto.DocumentTypeId, dto.IdDocumentNumber);
        var contact = new ContactInfo(dto.Email, dto.LandlinePhone, dto.CellPhone);
        var demographics = new EducationalDemographics(dto.NativeLanguageId, dto.EthnicSelfIdentificationId, dto.SecondLanguageIds);
        var profile = new StudentProfile(dto.HasElectronicDevices, dto.HasInternetAccess, dto.HasDisability, dto.Siblings, dto.ChildbirthTypeId);
        var familiars = dto.Familiars.Select(FamiliarFromDTO).ToList();

        return DStudent.Create(
            id: id,
            name: name,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            document: document,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation!.DistrictId,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            contact: contact,
            demographics: demographics,
            profile: profile,
            birthLocation: new DLocation(dto.BirthLocation.DepartmentId, dto.BirthLocation.ProvinceId, dto.BirthLocation.DistrictId),
            addressLocation: new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId),
            familiars: familiars
        );
    }

    public static DFamiliar FamiliarFromDTO(CreateFamiliarDTO dto)
    {
        var name = new PersonalName(dto.Names, dto.PaternalLastname, dto.MaternalLastname);
        var document = new IdentityDocument(dto.DocumentTypeId, dto.IdDocumentNumber);
        var contact = new ContactInfo(dto.Email, dto.LandlinePhone, dto.CellPhone);
        var demographics = new EducationalDemographics(dto.NativeLanguageId, dto.EthnicSelfIdentificationId, dto.SecondLanguageIds);
        var addressLocation = dto.AddressLocation != null
            ? new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId)
            : null;

        return DFamiliar.Create(
            id: 0,
            name: name,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            document: document,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation?.DistrictId ?? 0,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            contact: contact,
            demographics: demographics,
            levelOfEducationId: dto.LevelOfEducationId,
            occupation: dto.Occupation,
            workCenter: dto.WorkCenter,
            addressLocation: addressLocation,
            lives: dto.Lives,
            livesWithStudent: dto.LivesWithStudent,
            relationshipId: dto.RelationshipId,
            isGuardian: dto.IsGuardian
        );
    }

    public static DPerson PersonFromFamiliar(DFamiliar familiar)
    {
        return DPerson.Create(
            id: 0,
            name: familiar.Name,
            genderId: familiar.GenderId,
            birthDate: familiar.BirthDate,
            document: familiar.Document,
            address: familiar.Address,
            addressUbigeoId: familiar.AddressLocation?.DistrictId ?? 0,
            religionId: familiar.ReligionId,
            civilStateId: familiar.CivilStateId,
            contact: familiar.Contact
        );
    }
}
