using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class EnrollmentQueries : IEnrollmentQueries
{
    private readonly SRJDbContext _context;

    public EnrollmentQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<EnrollmentDTO>> GetByStudentAsync(int studentId)
    {
        return await _context.Enrollments
            .Where(e => e.StudentId == studentId)
            .OrderBy(e => e.Id)
            .Select(e => new EnrollmentDTO
            {
                id = e.Id,
                Code = e.Code,
                CodeNumber = e.CodeNumber,
                StudentId = e.StudentId!.Value,
                GradeOfferingShiftSectionId = e.GradeOfferingShiftSectionId,
                SchoolFeeConceptId = e.SchoolFeeConceptId,
                SchoolYearId = e.SchoolYearId,
                PreviousSchool = e.PreviousSchool
            })
            .ToListAsync();
    }

    public async Task<EnrollmentDTO?> GetLatestByStudentAsync(int studentId)
    {
        return await _context.Enrollments
            .Where(e => e.StudentId == studentId)
            .OrderByDescending(e => e.Id)
            .Select(e => new EnrollmentDTO
            {
                id = e.Id,
                Code = e.Code,
                CodeNumber = e.CodeNumber,
                StudentId = e.StudentId!.Value,
                GradeOfferingShiftSectionId = e.GradeOfferingShiftSectionId,
                SchoolFeeConceptId = e.SchoolFeeConceptId,
                SchoolYearId = e.SchoolYearId,
                PreviousSchool = e.PreviousSchool
            })
            .FirstOrDefaultAsync();
    }
}
