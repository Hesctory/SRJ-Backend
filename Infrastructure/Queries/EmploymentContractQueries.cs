using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class EmploymentContractQueries : IEmploymentContractQueries
{
    private readonly SRJDbContext _context;

    public EmploymentContractQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<EmploymentContractDTO> Items, int Total)> GetPagedAsync(int skip, int take, EmploymentContractFilter? filter = null)
    {
        var query = _context.EmploymentContracts.AsNoTracking().AsQueryable();

        if (filter?.StaffMemberId.HasValue == true)
            query = query.Where(ec => ec.StaffMemberId == filter.StaffMemberId.Value);

        if (filter?.SchoolYearId.HasValue == true)
            query = query.Where(ec => ec.SchoolYearId == filter.SchoolYearId.Value);

        if (filter?.JobPositionId.HasValue == true)
            query = query.Where(ec => ec.JobPositionId == filter.JobPositionId.Value);

        if (filter?.AreaId.HasValue == true)
            query = query.Where(ec => ec.AreaId == filter.AreaId.Value);

        var total = await query.CountAsync();
        var items = await query
            .Skip(skip).Take(take)
            .Select(ec => new EmploymentContractDTO
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
            })
            .ToListAsync();

        return (items, total);
    }

    public async Task<EmploymentContractDTO?> GetByIdAsync(int id)
    {
        return await _context.EmploymentContracts
            .AsNoTracking()
            .Where(ec => ec.Id == id)
            .Select(ec => new EmploymentContractDTO
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
            })
            .FirstOrDefaultAsync();
    }
}
