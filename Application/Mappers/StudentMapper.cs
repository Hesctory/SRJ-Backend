using SRJBackend.Application.DTOs;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Mappers;

public static class StudentMapper
{
    public static DStudent FromDTO(CreateStudentDTO dto, int id = 0)
    {
        var familiars = dto.Familiars.Select(FamiliarFromDTO).ToList();
        return new DStudent(
            id: id,
            names: dto.Names,
            paternalLastname: dto.PaternalLastname,
            maternalLastname: dto.MaternalLastname,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            documentTypeId: dto.DocumentTypeId,
            idDocumentNumber: dto.IdDocumentNumber,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation!.DistrictId,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            email: dto.Email,
            landlinePhone: dto.LandlinePhone,
            cellPhone: dto.CellPhone,
            nativeLanguageId: dto.NativeLanguageId,
            ethnicSelfIdentificationId: dto.EthnicSelfIdentificationId,
            secondLanguageIds: dto.SecondLanguageIds,
            hasElectronicDevices: dto.HasElectronicDevices,
            hasInternetAccess: dto.HasInternetAccess,
            birthLocation: new DLocation(dto.BirthLocation.DepartmentId, dto.BirthLocation.ProvinceId, dto.BirthLocation.DistrictId),
            addressLocation: new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId),
            hasDisability: dto.HasDisability,
            siblings: dto.Siblings,
            childbirthTypeId: dto.ChildbirthTypeId,
            familiars: familiars
        );
    }

    public static DStudent FromDTO(UpdateStudentDTO dto, int id = 0)
    {
        var familiars = dto.Familiars.Select(FamiliarFromDTO).ToList();
        return new DStudent(
            id: id,
            names: dto.Names,
            paternalLastname: dto.PaternalLastname,
            maternalLastname: dto.MaternalLastname,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            documentTypeId: dto.DocumentTypeId,
            idDocumentNumber: dto.IdDocumentNumber,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation!.DistrictId,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            email: dto.Email,
            landlinePhone: dto.LandlinePhone,
            cellPhone: dto.CellPhone,
            nativeLanguageId: dto.NativeLanguageId,
            ethnicSelfIdentificationId: dto.EthnicSelfIdentificationId,
            secondLanguageIds: dto.SecondLanguageIds,
            hasElectronicDevices: dto.HasElectronicDevices,
            hasInternetAccess: dto.HasInternetAccess,
            birthLocation: new DLocation(dto.BirthLocation.DepartmentId, dto.BirthLocation.ProvinceId, dto.BirthLocation.DistrictId),
            addressLocation: new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId),
            hasDisability: dto.HasDisability,
            siblings: dto.Siblings,
            childbirthTypeId: dto.ChildbirthTypeId,
            familiars: familiars
        );
    }

    public static DFamiliar FamiliarFromDTO(CreateFamiliarDTO dto)
    {
        var addressLocation = dto.AddressLocation != null
            ? new DLocation(dto.AddressLocation.DepartmentId, dto.AddressLocation.ProvinceId, dto.AddressLocation.DistrictId)
            : null;

        return new DFamiliar(
            id: 0,
            names: dto.Names,
            paternalLastname: dto.PaternalLastname,
            maternalLastname: dto.MaternalLastname,
            genderId: dto.GenderId,
            birthDate: dto.BirthDate,
            documentTypeId: dto.DocumentTypeId,
            idDocumentNumber: dto.IdDocumentNumber,
            address: dto.Address ?? string.Empty,
            addressUbigeoId: dto.AddressLocation?.DistrictId ?? 0,
            religionId: dto.ReligionId,
            civilStateId: dto.CivilStateId,
            email: dto.Email,
            landlinePhone: dto.LandlinePhone,
            cellPhone: dto.CellPhone,
            nativeLanguageId: dto.NativeLanguageId,
            ethnicSelfIdentificationId: dto.EthnicSelfIdentificationId,
            secondLanguageIds: dto.SecondLanguageIds,
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
        return new DPerson(
            id: 0,
            names: familiar.Names,
            paternalLastname: familiar.PaternalLastname,
            maternalLastname: familiar.MaternalLastname,
            genderId: familiar.GenderId,
            birthDate: familiar.BirthDate,
            documentTypeId: familiar.DocumentTypeId,
            idDocumentNumber: familiar.IdDocumentNumber,
            address: familiar.Address,
            addressUbigeoId: familiar.AddressLocation?.DistrictId ?? 0,
            religionId: familiar.ReligionId,
            civilStateId: familiar.CivilStateId,
            email: familiar.Email,
            landlinePhone: familiar.LandlinePhone,
            cellPhone: familiar.CellPhone
        );
    }
}
