using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class StaffMemberQueries : IStaffMemberQueries
{
    private readonly SRJDbContext _context;

    public StaffMemberQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<StaffMemberListDTO> Items, int Total)> GetPagedAsync(int skip, int take, StaffMemberFilter? filter = null)
    {
        var query = _context.StaffMembers.Include(s => s.Person).AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(filter?.FullName))
            query = query.Where(s =>
                EF.Functions.ILike(s.Person.Names, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.Person.PaternalLastname, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.Person.MaternalLastname, $"%{filter.FullName}%"));

        if (!string.IsNullOrWhiteSpace(filter?.DocumentNumber))
            query = query.Where(s => s.Person.IdDocumentNumber.Contains(filter.DocumentNumber));

        if (!string.IsNullOrWhiteSpace(filter?.EmployeeCode))
            query = query.Where(s => s.EmployeeCode != null && s.EmployeeCode.Contains(filter.EmployeeCode));

        if (filter?.IsActive.HasValue == true)
            query = query.Where(s => s.IsActive == filter.IsActive.Value);

        if (filter?.IsArchived.HasValue == true)
            query = query.Where(s => s.IsArchived == filter.IsArchived.Value);

        var total = await query.CountAsync();
        var items = await query
            .Skip(skip).Take(take)
            .Select(s => new StaffMemberListDTO
            {
                Id = s.PersonId,
                FullName = (s.Person.Names + " " + s.Person.PaternalLastname + " " + s.Person.MaternalLastname).Trim(),
                DocumentNumber = s.Person.IdDocumentNumber,
                EmployeeCode = s.EmployeeCode,
                ProfessionalTitle = s.ProfessionalTitle
            })
            .ToListAsync();

        return (items, total);
    }

    public async Task<StaffMemberDetailDTO?> GetByIdAsync(int id)
    {
        var s = await _context.StaffMembers
            .Include(s => s.Person)
                .ThenInclude(p => p.AddressUbigeo)
                    .ThenInclude(u => u.District)
                        .ThenInclude(d => d.Province)
            .Include(s => s.EmploymentContracts)
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.PersonId == id);

        if (s == null) return null;

        return new StaffMemberDetailDTO
        {
            Id = s.PersonId,
            Names = s.Person.Names,
            PaternalLastname = s.Person.PaternalLastname,
            MaternalLastname = s.Person.MaternalLastname,
            FullName = (s.Person.Names + " " + s.Person.PaternalLastname + " " + s.Person.MaternalLastname).Trim(),
            GenderId = s.Person.GenderId,
            BirthDate = s.Person.BirthDate,
            DocumentTypeId = s.Person.DocumentTypeId,
            IdDocumentNumber = s.Person.IdDocumentNumber,
            ReligionId = s.Person.ReligionId,
            CivilStateId = s.Person.CivilStateId,
            Address = s.Person.Address,
            AddressUbigeoId = s.Person.AddressUbigeoId,
            AddressLocation = s.Person.AddressUbigeo != null
                ? new LocationDTO
                {
                    DepartmentId = s.Person.AddressUbigeo.District.Province.DepartmentId,
                    ProvinceId = s.Person.AddressUbigeo.District.ProvinceId,
                    DistrictId = s.Person.AddressUbigeo.DistrictId
                }
                : new LocationDTO { DistrictId = s.Person.AddressUbigeoId },
            Email = s.Person.Email,
            LandlinePhone = s.Person.LandlinePhone,
            CellPhone = s.Person.CellPhone,
            LevelOfEducationId = s.LevelOfEducationId,
            ProfessionalTitle = s.ProfessionalTitle,
            EmployeeCode = s.EmployeeCode,
            PreviousInstitution = s.PreviousInstitution,
            SpouseName = s.SpouseName,
            SpouseDocumentNumber = s.SpouseDocumentNumber,
            SpouseOccupation = s.SpouseOccupation,
            NumberOfChildren = s.NumberOfChildren,
            Comment = s.Comment,
            IsActive = s.IsActive,
            IsArchived = s.IsArchived,
            Contracts = s.EmploymentContracts.Select(ec => new EmploymentContractDTO
            {
                Id = ec.Id,
                StaffMemberId = ec.StaffMemberId,
                InstitutionId = ec.InstitutionId,
                SchoolYearId = ec.SchoolYearId,
                JobPositionId = ec.JobPositionId,
                AreaId = ec.AreaId,
                StartDate = ec.StartDate,
                EndDate = ec.EndDate,
                Salary = ec.Salary
            }).ToList()
        };
    }
}
