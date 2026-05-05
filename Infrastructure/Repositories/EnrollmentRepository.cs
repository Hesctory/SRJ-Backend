using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EnrollmentRepository : IEnrollmentRepository
{
    private readonly SRJDbContext _context;

    public EnrollmentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int> CreateAsync(DEnrollment enrollment)
    {
        var e = new Enrollment
        {
            StudentId = enrollment.StudentId,
            GradeOfferingShiftSectionId = enrollment.SectionId,
            SchoolFeeConceptId = enrollment.SchoolFeeConceptId,
            Code = enrollment.Code,
            CodeNumber = enrollment.CodeNumber
        };
        _context.Enrollments.Add(e);
        await _context.SaveChangesAsync();
        return e.Id;
    }

    public async Task<bool> ExistsForStudentInYearAsync(int studentId, int schoolYearId)
    {
        return await _context.Enrollments
            .AnyAsync(e =>
                e.StudentId == studentId &&
                e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.SchoolYearId == schoolYearId);
    }

    public async Task<int?> GetSchoolYearIdForSectionAsync(int sectionId)
    {
        return await _context.GradeOfferingShiftSections
            .Where(s => s.Id == sectionId)
            .Select(s => s.GradeOfferingShift.GradeOffering.SchoolYearId)
            .FirstOrDefaultAsync();
    }

    public async Task<int> NextCodeNumberForYearAsync(int schoolYearId)
    {
        var maxCodeNumber = await _context.Enrollments
            .Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.SchoolYearId == schoolYearId)
            .MaxAsync(e => (int?)e.CodeNumber);
        return (maxCodeNumber ?? 0) + 1;
    }
}