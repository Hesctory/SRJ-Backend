using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class StaffMemberRepository : IStaffMemberRepository
{
    private readonly SRJDbContext _context;

    public StaffMemberRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task CreateAsync(DStaffMember staffMember, int personId)
    {
        var s = new StaffMember
        {
            PersonId = personId,
            LevelOfEducationId = staffMember.Profile.LevelOfEducationId,
            ProfessionalTitle = staffMember.Profile.ProfessionalTitle,
            EmployeeCode = staffMember.Profile.EmployeeCode,
            PreviousInstitution = staffMember.Profile.PreviousInstitution,
            SpouseName = staffMember.Profile.SpouseName,
            SpouseDocumentNumber = staffMember.Profile.SpouseDocumentNumber,
            SpouseOccupation = staffMember.Profile.SpouseOccupation,
            NumberOfChildren = staffMember.Profile.NumberOfChildren,
            Comment = staffMember.Profile.Comment,
            IsActive = true,
            IsArchived = false
        };
        _context.StaffMembers.Add(s);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(DStaffMember staffMember)
    {
        var s = await _context.StaffMembers.FindAsync(staffMember.Id);
        if (s == null) return;
        s.LevelOfEducationId = staffMember.Profile.LevelOfEducationId;
        s.ProfessionalTitle = staffMember.Profile.ProfessionalTitle;
        s.EmployeeCode = staffMember.Profile.EmployeeCode;
        s.PreviousInstitution = staffMember.Profile.PreviousInstitution;
        s.SpouseName = staffMember.Profile.SpouseName;
        s.SpouseDocumentNumber = staffMember.Profile.SpouseDocumentNumber;
        s.SpouseOccupation = staffMember.Profile.SpouseOccupation;
        s.NumberOfChildren = staffMember.Profile.NumberOfChildren;
        s.Comment = staffMember.Profile.Comment;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> ExistsAsync(int id)
        => await _context.StaffMembers.AnyAsync(s => s.PersonId == id);

    public async Task<bool> IsStaffMemberAsync(int personId)
        => await _context.StaffMembers.AnyAsync(s => s.PersonId == personId);

    public async Task<bool> TryDeleteAsync(int id)
    {
        var s = await _context.StaffMembers.FindAsync(id);
        if (s == null) return false;
        try
        {
            _context.StaffMembers.Remove(s);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (DbUpdateException)
        {
            _context.Entry(s).State = EntityState.Unchanged;
            return false;
        }
    }

    public async Task ArchiveAsync(int id)
    {
        var s = await _context.StaffMembers.FindAsync(id);
        if (s == null) return;
        s.IsArchived = true;
        await _context.SaveChangesAsync();
    }

    public async Task UnarchiveAsync(int id)
    {
        var s = await _context.StaffMembers.FindAsync(id);
        if (s == null) return;
        s.IsArchived = false;
        await _context.SaveChangesAsync();
    }
}
