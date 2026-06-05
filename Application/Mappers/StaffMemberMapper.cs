using SRJBackend.Application.DTOs;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.Mappers;

public static class StaffMemberMapper
{
    public static DStaffMember FromDTO(CreateStaffMemberDTO dto, int id = 0)
    {
        var name = new PersonalName(dto.Names, dto.PaternalLastname, dto.MaternalLastname);
        var document = new IdentityDocument(dto.DocumentTypeId, dto.IdDocumentNumber);
        var contact = new ContactInfo(dto.Email, dto.LandlinePhone, dto.CellPhone);
        var profile = BuildProfile(dto);

        return DStaffMember.Create(
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
            profile: profile);
    }

    public static DStaffMember FromDTO(UpdateStaffMemberDTO dto, int id = 0)
    {
        var name = new PersonalName(dto.Names, dto.PaternalLastname, dto.MaternalLastname);
        var document = new IdentityDocument(dto.DocumentTypeId, dto.IdDocumentNumber);
        var contact = new ContactInfo(dto.Email, dto.LandlinePhone, dto.CellPhone);
        var profile = BuildProfile(dto);

        return DStaffMember.Create(
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
            profile: profile);
    }

    public static DEmploymentContract ContractFromDetails(ContractDetailsDTO dto, int staffMemberId)
        => DEmploymentContract.Create(
            staffMemberId: staffMemberId,
            institutionId: dto.InstitutionId,
            schoolYearId: dto.SchoolYearId,
            jobPositionId: dto.JobPositionId,
            areaId: dto.AreaId,
            startDate: dto.StartDate,
            endDate: dto.EndDate,
            salary: dto.Salary);

    public static DEmploymentContract ContractFromDTO(CreateEmploymentContractDTO dto)
        => DEmploymentContract.Create(
            staffMemberId: dto.StaffMemberId,
            institutionId: dto.InstitutionId,
            schoolYearId: dto.SchoolYearId,
            jobPositionId: dto.JobPositionId,
            areaId: dto.AreaId,
            startDate: dto.StartDate,
            endDate: dto.EndDate,
            salary: dto.Salary);

    private static StaffProfile BuildProfile(CreateStaffMemberDTO dto)
        => new StaffProfile(dto.LevelOfEducationId, dto.ProfessionalTitle, dto.EmployeeCode,
                            dto.PreviousInstitution, dto.SpouseName, dto.SpouseDocumentNumber,
                            dto.SpouseOccupation, dto.NumberOfChildren, dto.Comment);

    private static StaffProfile BuildProfile(UpdateStaffMemberDTO dto)
        => new StaffProfile(dto.LevelOfEducationId, dto.ProfessionalTitle, dto.EmployeeCode,
                            dto.PreviousInstitution, dto.SpouseName, dto.SpouseDocumentNumber,
                            dto.SpouseOccupation, dto.NumberOfChildren, dto.Comment);
}
